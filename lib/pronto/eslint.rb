require 'pronto'
require 'eslintrb'

module Pronto
  class ESLint < Runner
    DEFAULT_EXTENSIONS = %w[.js .es6 .js.es6 .jsx].freeze

    def run
      return [] unless @patches

      @patches.select { |patch| patch.additions > 0 }
        .select { |patch| js_file?(patch.new_file_full_path) }
        .map { |patch| inspect(patch) }
        .flatten.compact
    end

    def inspect(patch)
      offences = Eslintrb.lint(patch.new_file_full_path, options).compact

      fatals = offences.select { |offence| offence['fatal'] }
        .map { |offence| new_message(offence, nil) }

      return fatals if fatals && !fatals.empty?

      offences.map do |offence|
        patch.added_lines.select { |line| line.new_lineno == offence['line'] }
          .map { |line| new_message(offence, line) }
      end
    end

    def options
      if ENV['ESLINT_CONFIG']
        JSON.parse(IO.read(ENV['ESLINT_CONFIG']))
      else
        File.exist?('.eslintrc') ? :eslintrc : :defaults
      end
    end

    def new_message(offence, line)
      path = line ? line.patch.delta.new_file[:path] : '.eslintrc'
      level = line ? :warning : :fatal

      Message.new(path, line, level, offence['message'], nil, self.class)
    end

    def js_file?(path)
      extensions.include?(File.extname(path))
    end

    def extensions
      @extensions ||= pronto_eslint_config.fetch('extensions', DEFAULT_EXTENSIONS)
    end

    def pronto_eslint_config
      @pronto_eslint_config ||= Pronto::ConfigFile.new.to_h['eslint'] || {}
    end
  end
end
