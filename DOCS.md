> This docs file is temporary, I'm planning to make a better version at [my website](https://errorsyntax.neocities.org)

<details>
  <summary>.neoignore</summary>
  
## `.neoignore`

`.neoignore` is a file similar to `.gitignore` from Git. The concept is the same: exclude specific files from deploy.

To work with it, first you need to create a file exactly named ".neoignore" in your root:

```bash
my-project/ # <-- project root
│
├── ultra-secret-dir/ # <-- ultra secret directory
│   └── ultra-secret-file
│
├── secret-file.txt # <-- secret file
├── .neoignore # <-- here it is!
├── blog.html # <-- your other cool files
├── index.html
├── not_found.html
├── robots.txt
└── style.css
```
Next step is to put the names of the the secret files and directories (that ones you don't want to go together in your project) inside `.neoignore`:

```bash
# inside of .neoignore...
ultra-secret-dir/
secret-file.txt
```
Everything inside it, Neogities will ignore and won't deploy to your website.

**Things to keep in mind**
- The file needs to be exactly named ".neoignore". Otherwise, Neogities won't find it.
- The paths are relatives to .neoignore.
- If you don't put it in root, Neogities won't be able to identify it.

If you don't do this, Neogities won't exclude files correctly, deploying it and your files to remote (i think you don't want this).