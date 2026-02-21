#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

#include <curl/curl.h>
#include <jansson.h>
#include <string.h>

#include <pwd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <dirent.h>

#include <termios.h>

#include <readline/readline.h>
#include <readline/history.h>

// -------------------------
// HTTP response buffer
// -------------------------
struct response {
    	char *data;
    	size_t len;
}; 

static size_t write_cb(
	void *ptr, 
	size_t size, 
	size_t nmemb, 
	void *userdata
)
{
    	struct response *r = (struct response*)userdata;
    	size_t chunk = size * nmemb;
    	char *tmp = realloc(r->data, r->len + chunk + 1);
    	if (!tmp) return 0;
    	r->data = tmp;
    	memcpy(r->data + r->len, ptr, chunk);
    	r->len += chunk;
    	r->data[r->len] = '\0';
    	return chunk;
}

// -------------------------
// HTTP helpers
// -------------------------
static int perform_request(
    	const char *url,
    	const char *api_key,
    	const char *post_fields,
    	struct response *resp,
    	curl_mime *mime
)
{
    	CURL *curl = curl_easy_init();
    	if (!curl) return 1;

    	resp->data = malloc(1);
    	resp->len = 0;
	resp->data[0] = '\0';

    	struct curl_slist *headers = NULL;
	
	if (api_key && strlen(api_key) > 0) {
		char auth_header[512];
	    	snprintf(auth_header, sizeof(auth_header),
				"Authorization: Bearer %s", api_key);
	    	headers = curl_slist_append(headers, auth_header);
	}

    	curl_easy_setopt(curl, CURLOPT_URL, url);
    	
	if (headers)
		curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    	
	/* SSL hardening */
	curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 1L);
	curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 2L);
    	
	curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 0L); // política
	
	curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 10L);
	curl_easy_setopt(curl, CURLOPT_TIMEOUT, 60L);

	curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_cb);
    	curl_easy_setopt(curl, CURLOPT_WRITEDATA, resp);

	if (post_fields) {
    	    	curl_easy_setopt(curl, CURLOPT_POST, 1L);
        	curl_easy_setopt(curl, CURLOPT_POSTFIELDS, post_fields);
    	}

    	if (mime)
    	    	curl_easy_setopt(curl, CURLOPT_MIMEPOST, mime);

    	CURLcode res = curl_easy_perform(curl);

    	curl_slist_free_all(headers);
    	curl_easy_cleanup(curl);

    	long http_code = 0;
	curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);

	if (res != CURLE_OK || http_code >= 400) {
	    	curl_slist_free_all(headers);
	    	curl_easy_cleanup(curl);
	    	free(resp->data);
	    	return 2;
	}

    	return 0;
}

// -------------------------
// info — GET /api/info
// -------------------------
int neocities_info(
	const char *sitename,
	char** out
)
{
    	char url[512];
    	if (sitename)
    	    snprintf(url, sizeof(url), "https://neocities.org/api/info?sitename=%s", sitename);
    	else
    	    snprintf(url, sizeof(url), "https://neocities.org/api/info");

    	struct response resp;
    	int ret = perform_request(url, NULL, NULL, &resp, NULL);
    	if (ret) return ret;

	*out = resp.data;
    	
	return 0;
}

// -------------------------
// list — GET /api/list
// -------------------------
int neocities_list(
	const char *api_key,
	const char *path,
	char **out
)
{
	char url[512];
    	if (path) snprintf(url, sizeof(url), "https://neocities.org/api/list?path=%s", path);
    	else snprintf(url, sizeof(url), "https://neocities.org/api/list");

    	struct response resp;
    	int ret = perform_request(url, api_key, NULL, &resp, NULL);
	if (ret) return ret;

    	*out = resp.data;	
	return 0;
}

// -------------------------
// delete — POST /api/delete
// -------------------------
int neocities_delete(
	const char *api_key,
        const char **filenames,
        size_t count,
        char **response
)
{
	char body[1024] = "";
    	for (size_t i=0; i<count; i++) {
    	    char tmp[256];
    	    snprintf(tmp, sizeof(tmp), "filenames[]=%s&", filenames[i]);
    	    strncat(body, tmp, sizeof(body)-strlen(body)-1);
    	} 
    	struct response resp;
    	int ret = perform_request(
	    "https://neocities.org/api/delete",
	    api_key,
	    body,
	    &resp,
	    NULL
	);
	if (ret) return ret;
    	*response = resp.data;
    	return 0;
}

// -------------------------
// upload — POST /api/upload
// (multipart/form-data)
// -------------------------
int neocities_upload(
	const char *api_key,
    	const char **local_files,
   	const char **remote_names,
    	size_t count,
    	char **response
)
{
	if (!api_key || strlen(api_key) == 0)
		return 3;

	CURL *curl = curl_easy_init();
    	if (!curl) return 1;

    	struct response resp;
    	resp.data = malloc(1);
    	resp.len = 0;
	resp.data[0] = '\0';

    	curl_easy_setopt(curl, CURLOPT_URL, "https://neocities.org/api/upload");
    	curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_cb);
    	curl_easy_setopt(curl, CURLOPT_WRITEDATA, &resp);

    	curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 1L);
	curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 2L);
	curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 0L);
	curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 10L);
	curl_easy_setopt(curl, CURLOPT_TIMEOUT, 60L);


	curl_easy_setopt(curl, CURLOPT_USERPWD, NULL);
    	
	struct curl_slist *headers = NULL;
	char auth_header[512];
	snprintf(auth_header, sizeof(auth_header),
	    "Authorization: Bearer %s", api_key);
	
	headers = curl_slist_append(headers, auth_header);
	curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

    	curl_mime *form = curl_mime_init(curl);
    	for (size_t i=0; i<count; i++) {
    	    curl_mimepart *part = curl_mime_addpart(form);
    	    curl_mime_name(part, remote_names[i]);
    	    curl_mime_filedata(part, local_files[i]);
    	}
    	curl_easy_setopt(curl, CURLOPT_MIMEPOST, form);

    	CURLcode res = curl_easy_perform(curl);
    	curl_mime_free(form);
    	curl_slist_free_all(headers);
	curl_easy_cleanup(curl);

    	if (res != CURLE_OK) { free(resp.data); return 2; }

    	*response = resp.data;
    	return 0;
}

char* home()
{
	struct passwd *u;
	u = getpwuid(getuid());

	if (!u) {
		perror("invalid return of getpwuid() function.\n");
		return NULL;
	}

	return u->pw_dir;
}

// DIR_NAME deve ser o nome do diretório, não o caminho (ex: task)
// Se HOME = NULL, a função assume que a pasta que quer está fora da pasta /home/usuário

// Importante: essa função retorna um char*. Para abrir o diretório retornado, você deve usar
// a função opendir() com o valor retornado de get_dir()
char* get_dir(const char* HOME, const char* DIR_NAME) {
	if (DIR_NAME[0] == '~') {
		perror("get_dir doesn't expand '~'");
		return NULL;
	}
	if (DIR_NAME[0] == '/') {
		perror("DIR_NAME can't begin with '/'");
		return NULL;
	}

	const char *prefix = HOME ? HOME : "";

	int size = strlen(prefix) + 1 + strlen(DIR_NAME) + 1;
	char *DIR_FINAL = malloc(size);
	if (!DIR_FINAL) {
		perror("malloc failed");
		return NULL;
	}

	sprintf(DIR_FINAL, "%s/%s", prefix, DIR_NAME);

	DIR *dir = opendir(DIR_FINAL);
	if (!dir) {
		if (mkdir(DIR_FINAL, 0755) != 0) {
			fprintf(stderr, "'%s' cannot be created\n", DIR_FINAL);
			free(DIR_FINAL);
			return NULL;
		}
	} else {
		closedir(dir);
	}

	return DIR_FINAL;
}

char* get_file(const char* ROOT, const char* FILE_NAME) {
	char* FINAL_FILE;

	FINAL_FILE = malloc(strlen(ROOT) + strlen(FILE_NAME) + 1);
	sprintf(FINAL_FILE, "%s/%s", ROOT, FILE_NAME);

	return FINAL_FILE;
}

struct termios orig_termios;

void disable_raw_mode() { tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_termios); }
void enable_raw_mode() {
    	tcgetattr(STDIN_FILENO, &orig_termios);
    	atexit(disable_raw_mode);
    	struct termios raw = orig_termios;
    	raw.c_lflag &= ~(ECHO | ICANON);
    	raw.c_cc[VMIN] = 0; raw.c_cc[VTIME] = 1;
    	tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
}

int read_key() {
	char c; int n = read(STDIN_FILENO, &c, 1);
	if (n == 1) {
		if (c == '\033') {
			char seq[2];
			if (read(STDIN_FILENO, &seq[0], 1) != 1) return '\033';
			if (read(STDIN_FILENO, &seq[1], 1) != 1) return '\033';
			if (seq[0] == '[') {
				switch(seq[1]) {
					case 'A': return 1000; // cima
					case 'B': return 1001; // baixo
				}
			}
			return 0;
		} 
		return c;
		}
	return 0;
}

int menu(char *titles[], int n_titles, char *options[], int n_options, char *footer, int circular) {
	int selected = 0;
	enable_raw_mode();
	
	int total_lines = n_titles + n_options + (footer ? 1 : 0);
	
	while (1) {
		// só imprime normalmente, abaixo do que já está
		for (int i = 0; i < n_titles; i++) printf("%s\n", titles[i]);
		for (int i = 0; i < n_options; i++) {
			if (i == selected) printf("> %s\n", options[i]);
			else printf("  %s\n", options[i]);
		} 
		if (footer) printf("%s\n", footer);
			
		int key = read_key();
		if (key == 1000) { selected--; if (circular && selected < 0) selected = n_options - 1; if (!circular && selected < 0) selected = 0; }
		else if (key == 1001) { selected++; if (circular && selected >= n_options) selected = 0; if (!circular && selected >= n_options) selected = n_options - 1; }
		else if (key == '\n') break;
		else if (key == 27) { selected = -1; break; }
			
		// depois de desenhar, sobe o cursor e apaga menu antigo
		for (int i = 0; i < total_lines; i++) {
			printf("\033[1A\033[2K"); // sobe 1 linha e limpa
		} 
	} 
	
	// move cursor pro topo do menu antigo
	printf("\033[%dA", total_lines); 
		
	// limpa cada linha
	for (int i = 0; i < total_lines; i++) {
		printf("\033[2K");         // limpa a linha
		if (i != total_lines-1) printf("\033[1B"); // desce linha
	} 
		
	// volta cursor pro topo do menu
	printf("\033[%dA", total_lines-1); 
		
	disable_raw_mode();
	return selected;
}

const char* DATA_DIR = ".local/share/neogities";
const char* CONFIG_DIR = ".config/neogities";

const char* CONFIG_FILE = "neogities.conf";
const char* ACCESS_FILE = "credentials";

int main() {
	static const char* version = "v0.1.0";

	const char* DEF_DATA_DIR = get_dir(home(), DATA_DIR);
	const char* DEF_CONFIG_DIR = get_dir(home(), DATA_DIR);

	const char* DEF_CONFIG_FILE = get_file(DEF_CONFIG_DIR, CONFIG_FILE);
	const char* DEF_ACCESS_FILE = get_file(DEF_DATA_DIR, ACCESS_FILE);

	srand(time(NULL) ^ getpid());

	int a = rand() % 2;
	int b = rand() % 2;

	static const char* eyes[] = { "-_o", "o_o" };
	static const char* mouths[] = { "-", "~" };
	
	const char* eye = eyes[a];
	const char* mouth = mouths[b];
	
	static const char *logo =
	"|\\---/|---------------o\n"
	"| %s |   Neogities  / \\\n"
	" \\_%s_/    %s    /   o\n"
	"                   o\n";

	printf("Hello! You're not logged in.\n\n");
	printf(logo, eye, mouth, version);

	/* char *titles[] = {"Meu Menu"};
	char *options[] = {"Opção 1", "Opção 2", "Opção 3"};
	char *footer = "Use setas ↑↓ e Enter para selecionar. ESC para sair.";
	int choice = menu(titles, 1, options, 3, footer, 1);

	printf("Selecionou: %d\n", choice); */

	/* char *input = readline("Nome: ");  // mostra prompt e permite editar
    	if (input != NULL) {
    	    printf("Você digitou: %s\n", input);
    	}

	free(input); */
	free((char*)DEF_DATA_DIR);
	free((char*)DEF_CONFIG_DIR);
	free((char*)DEF_CONFIG_FILE);
	free((char*)DEF_ACCESS_FILE);
} 
