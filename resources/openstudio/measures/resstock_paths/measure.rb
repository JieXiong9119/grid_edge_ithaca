class ResstockPaths < OpenStudio::Measure::ModelMeasure

  def name
    return 'Resstock Paths'
  end

  def description
    return 'This measure copies files needed for running OpenStudio models downloaded from ResStock, in the expected paths'
  end

  def modeler_description
    return 'Copy files for ResStock simulation to correct paths'
  end

  def run(model, runner, usr_args)
    super(model, runner, usr_args)

    return false unless runner.validateUserArguments(arguments(model), usr_args)

    require 'fileutils'

    # 1. Copy in.schedules.csv to run directory
    file_name = 'in.schedules.csv'
    run_dir = runner.workflow.absoluteRunDir.to_s
    source_path = File.expand_path(File.join(run_dir, '..', 'models', file_name))
    target_path = File.join(run_dir, file_name)

    if File.exist?(source_path)
      FileUtils.cp(source_path, target_path)
      runner.registerInfo("Copied #{file_name} to run directory: #{target_path}")
    else
      runner.registerInfo("CSV not found at: #{source_path}")
      return false
    end

    # 2. Copy home.xml to models/var/simdata/openstudio/run/
    home_file = 'home.xml'
    home_source = File.expand_path(File.join(run_dir, '..', 'models', home_file))
    nested_target_dir = File.expand_path(File.join(run_dir, '..', 'models', 'var', 'simdata', 'openstudio', 'run'))
    FileUtils.mkdir_p(nested_target_dir)
    home_target = File.join(nested_target_dir, home_file)

    if File.exist?(home_source)
      FileUtils.cp(home_source, home_target)
      runner.registerInfo("Copied #{home_file} to #{home_target}")
    else
      runner.registerInfo("home.xml not found at: #{home_source}")
      return false
    end

    return true
  end
end

ResstockPaths.new.registerWithApplication
