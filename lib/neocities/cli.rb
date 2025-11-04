require 'pathname'
require 'pastel'
require 'tty/table'
require 'tty/prompt'
require 'fileutils'
require 'json'
require 'whirly'
require 'time'
require File.join(File.dirname(__FILE__), 'client')

module Neocities
  class CLI
    SUBCOMMANDS = %w[upload delete list info push logout pizza pull].freeze
    HELP_SUBCOMMANDS = %w[-h --help help].freeze
    PENELOPE_EYES = %w[o ~ O].freeze
    PENELOPE_MOUTHS = %w[^ o ~ - v U].freeze

    def initialize(argv)
      @argv = argv.dup
      @subcmd = @argv.first
      @subargs = @argv[1..-1]
      @pastel = Pastel.new(eachline: "\n")
      @prompt = TTY::Prompt.new
      @api_key = ENV['NEOCITIES_API_KEY']
      @app_config_path = File.join(self.class.app_config_path('neocities'), 'config.json')
    end

    # -------------------------
    # MAIN ENTRY
    # -------------------------
    def run
      handle_version

      if help_request?
        display_help_for_subcommand(@subargs[0]) if SUBCOMMANDS.include?(@subargs[0])
        display_help
      end

      load_api_key_or_login
      @client = @api_key ? Neocities::Client.new(api_key: @api_key) : @client

      send @subcmd
    end

    # -------------------------
    # SUBCOMMANDS
    # -------------------------
    def push
      display_push_help if @subargs.empty?

      parse_push_options

      unless @local_path
        display_response(result: 'error', message: 'No local path provided')
        display_push_help
      end

      root_path = Pathname.new(@local_path)
      unless root_path.exist? && root_path.directory?
        display_response(result: 'error', message: "Invalid directory: #{root_path}")
        display_push_help
      end

      puts @pastel.green.bold('Dry run: nothing will actually be uploaded') if @dry_run

      prune_remote if @prune
      files_to_upload(root_path).each { |file| upload_file(file, root_path) }
    end

    def upload
      display_upload_help if @subargs.empty?

      dir = ''
      while arg = @subargs.shift
        case arg
        when '-d' then dir = @subargs.shift
        when /^-/ then puts @pastel.red.bold("Unknown option: #{arg.inspect}"); display_upload_help
        else
          path = Pathname.new(arg)
          if !path.exist?
            display_response(result: 'error', message: "#{path} does not exist locally.")
            next
          end

          if path.directory?
            puts "#{path} is a directory, skipping (use push command)"
            next
          end

          remote_path = ['/', dir, path.basename.to_s].join('/').gsub(%r{/+}, '/')
          puts @pastel.bold("Uploading #{path} to #{remote_path} ...")
          resp = @client.upload(path, remote_path)
          display_response(resp)
        end
      end
    end

    def delete
      display_delete_help if @subargs.empty?

      @subargs.each do |file|
        puts @pastel.bold("Deleting #{file} ...")
        resp = @client.delete(file)
        display_response(resp)
      end
    end

    def list
      @detail = @subargs.delete('-d')
      @subargs[0] = nil if @subargs.delete('-a')

      resp = @client.list(@subargs[0])
      return display_response(resp) if resp[:result] == 'error'

      if @detail
        table = [['Path', 'Size', 'Updated'].map { |h| @pastel.bold(h) }]
        resp[:files].each do |file|
          table << [
            @pastel.send(file[:is_directory] ? :blue : :green).bold(file[:path]),
            file[:size] || '',
            file[:updated_at] ? Time.parse(file[:updated_at]).localtime : ''
          ]
        end
        puts TTY::Table.new(table).to_s
      else
        resp[:files].each { |file| puts @pastel.send(file[:is_directory] ? :blue : :green).bold(file[:path]) }
      end
    end

    def info
      resp = @client.info(@subargs[0] || @sitename)
      return display_response(resp) if resp[:result] == 'error'

      table = resp[:info].map do |k, v|
        v = Time.parse(v).localtime if v && %i[created_at last_updated].include?(k)
        [@pastel.bold(k.to_s), v]
      end
      puts TTY::Table.new(table).to_s
    end

    def logout
      confirmed = @subargs.delete('-y')
      if confirmed
        FileUtils.rm(@app_config_path)
        puts @pastel.bold('API key removed.')
      else
        display_logout_help
      end
    end

    def pull
      quiet = %w[--quiet -q].include?(@subargs[0])
      file = File.read(@app_config_path)
      data = JSON.parse(file)

      last_pull = data['LAST_PULL'] || {}
      Whirly.start spinner: ['😺', '😸', '😹'], status: "Pulling files for #{@pastel.bold @sitename}" if quiet

      resp = @client.pull(@sitename, last_pull['time'], last_pull['loc'], quiet)

      data['LAST_PULL'] = { 'time' => Time.now, 'loc' => Dir.pwd }
      File.write(@app_config_path, data.to_json)
    rescue StandardError => ex
      Whirly.stop if quiet
      puts @pastel.red.bold("\nFatal error occurred")
      puts @pastel.red(ex)
    ensure
      exit
    end

    def pizza
      excuses = [
        "Sorry, no pineapple today.",
        "All toppings are currently missing.",
        "Pizza gods demand rest."
      ]
      puts @pastel.bright_red(excuses.sample)
      exit
    end

    # -------------------------
    # HELPERS
    # -------------------------
    def display_response(resp)
      case resp[:result]
      when 'success'
        puts "#{@pastel.green.bold('SUCCESS:')} #{resp[:message]}"
      when 'error'
        color = resp[:error_type] == 'file_exists' ? :yellow : :red
        puts "#{@pastel.send(color).bold('ERROR:')} #{resp[:message]}#{resp[:error_type] ? " (#{resp[:error_type]})" : ''}"
      end
    end

    def handle_version
      return unless @argv[0] == 'version'

      puts Neocities::VERSION
      exit
    end

    def help_request?
      HELP_SUBCOMMANDS.include?(@subcmd) || @subargs.join('').match?(HELP_SUBCOMMANDS.join('|'))
    end

    def display_help_for_subcommand(subcmd)
      send("display_#{subcmd}_help") rescue display_help
    end

    # -------------------------
    # PUSH LOGIC HELPERS
    # -------------------------
    def parse_push_options
      @use_gitignore = false
      @excluded_files = []
      @dry_run = false
      @prune = false
      @local_path = nil

      while arg = @subargs.shift
        case arg
        when '--gitignore' then @use_gitignore = true
        when '-e' then @excluded_files << @subargs.shift
        when '--dry-run' then @dry_run = true
        when '--prune' then @prune = true
        else
          if arg.start_with?('-')
            puts @pastel.red.bold("Unknown option: #{arg.inspect}")
            display_push_help
          else
            @local_path = arg
          end
        end
      end
    end

    def files_to_upload(root_path)
      ignore_patterns = load_ignore_patterns
      files = []

      require 'find'
      Find.find(root_path) do |file|
        next if ignored?(file, root_path, ignore_patterns)
        files << Pathname.new(file) unless File.directory?(file)
      end

      files
    end

    def ignored?(file, root_path, patterns)
      relative = Pathname.new(file).relative_path_from(root_path).to_s
      patterns.any? { |pattern| relative == pattern || relative.start_with?("#{pattern}/") }
    end

    def load_ignore_patterns
      patterns = []

      [".neoignore", ".gitignore"].each do |f|
        next unless File.exist?(f)
        File.readlines(f).map(&:strip).reject(&:empty?).each { |line| patterns << line.chomp('/') }
      end

      patterns << @excluded_files if @excluded_files.any?
      patterns.flatten
    end

    def upload_file(file, root_path)
      relative_path = file.relative_path_from(root_path)
      print @pastel.bold("Uploading #{file} ... ")
      resp = @client.upload(file, relative_path, @dry_run)

      case resp[:result]
      when 'success' then puts @pastel.green.bold('SUCCESS')
      when 'error'
        if resp[:error_type] == 'file_exists'
          puts @pastel.yellow.bold('EXISTS')
        else
          puts
          display_response(resp)
        end
      end
    end

    def prune_remote
      resp = @client.list
      resp[:files].each do |file|
        remote_file = Pathname.new(File.join(@local_path, file[:path]))
        next if remote_file.exist?

        print @pastel.bold("Deleting #{file[:path]} ... ")
        resp = @client.delete_wrapper_with_dry_run(file[:path], @dry_run)
        puts resp[:result] == 'success' ? @pastel.green.bold('SUCCESS') : display_response(resp)
      end
    end

    # -------------------------
    # CONFIG / LOGIN
    # -------------------------
    def load_api_key_or_login
      return if @api_key

      begin
        data = JSON.parse(File.read(@app_config_path))
        @api_key = data['API_KEY']&.strip
        @sitename = data['SITENAME']
      rescue Errno::ENOENT
        login
      end
    end

    def login
      puts "Please login to get your API key:"
      @sitename ||= @prompt.ask('Sitename:', default: ENV['NEOCITIES_SITENAME'])
      password = @prompt.mask('Password:', default: ENV['NEOCITIES_PASSWORD'])

      @client = Neocities::Client.new(sitename: @sitename, password: password)
      resp = @client.key

      if resp[:api_key]
        FileUtils.mkdir_p(Pathname(@app_config_path).dirname)
        File.write(@app_config_path, { API_KEY: resp[:api_key], SITENAME: @sitename }.to_json)
        @api_key = resp[:api_key]
        puts "API key stored at #{@app_config_path}."
      else
        display_response(resp)
        exit
      end
    end

    # -------------------------
    # HELP / DISPLAY
    # -------------------------
    def display_help
      banner
      puts <<~HELP
        Subcommands:
          push      Recursively upload a local directory
          upload    Upload individual files
          delete    Delete files
          list      List files
          info      Show site info
          logout    Remove API key
          version   Show version
          pull      Pull latest files
          pizza     Order a free pizza
      HELP
      exit
    end

    def banner
      puts <<~BANNER

        |\\---/|
        | #{PENELOPE_EYES.sample}_#{PENELOPE_EYES.sample} |  #{@pastel.cyan.bold 'Neogities CLI'}
         \\_#{PENELOPE_MOUTHS.sample}_/

      BANNER
    end

    def display_push_help
      puts <<~HELP
        Usage: push [options] PATH
        Options:
          --gitignore      Use .gitignore patterns
          -e FILE          Exclude specific file
          --dry-run        Show what would be uploaded without uploading
          --prune          Delete remote files not present locally
      HELP
      exit
    end

    def display_upload_help
      puts <<~HELP
        Usage: upload [options] FILES...
        Options:
          -d DIR           Remote directory to upload into
      HELP
      exit
    end

    def display_delete_help
      puts <<~HELP
        Usage: delete FILES...
        Deletes the specified remote files.
      HELP
      exit
    end

    def display_list_help
      puts <<~HELP
        Usage: list [PATH]
        Options:
          -d    Show detailed list with sizes and update dates
          -a    List all files including hidden
      HELP
      exit
    end

    def display_logout_help
      puts <<~HELP
        Usage: logout -y
        Removes stored API key.
      HELP
      exit
    end

    # -------------------------
    # CONFIG PATH
    # -------------------------
    def self.app_config_path(name)
      home = ENV['HOME'] || ENV['USERPROFILE']
      xdg = ENV['XDG_CONFIG_HOME']
      case RUBY_PLATFORM
      when /win32/ then ENV['LOCALAPPDATA'] || File.join(home, 'Local Settings', 'Application Data', name)
      when /darwin/ then File.join(home, 'Library', 'Application Support', name)
      else xdg ? File.join(xdg, name) : File.join(home, '.config', name)
      end
    end
  end
end
