# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

class AddOutputs < OpenStudio::Measure::ModelMeasure
  def name
    return 'add_outputs'
  end

  def description
    return 'This measure adds output variables and creates required output reports'
  end

  def modeler_description
    return 'This measure adds output variables and creates required output reports'
  end

  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # Most meters only exist in EnergyPlus when a matching component is present
    # (e.g. Cooling:Electricity needs a cooling coil, WaterSystems:NaturalGas a
    # gas water heater). Referencing a missing meter from an EMS sensor is a fatal
    # EnergyPlus error, and the model objects cannot reliably predict which meters
    # EnergyPlus will create. Only Electricity:Facility is guaranteed, so every
    # other meter is opt-in (the load tables only need Electricity:Facility).
    include_extra_meters = OpenStudio::Measure::OSArgument.makeBoolArgument('include_extra_meters', false)
    include_extra_meters.setDisplayName('Include end-use, PV and non-electric fuel meters')
    include_extra_meters.setDefaultValue(false)
    args << include_extra_meters
    return args
  end

  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    include_extra_meters = runner.getBoolArgumentValue('include_extra_meters', user_arguments)

    # -------------------------------------------------------------------------
    # Sanitize a string for use as an EMS identifier.
    # EMS names: alphanumeric + underscore only, max 100 chars.
    # Keep limit at 60 to leave room for suffixes (_Sensor, _kWh).
    # -------------------------------------------------------------------------
    def sanitize_ems_name(name)
      name.gsub(/[^A-Za-z0-9_]/, '')[0..59]
    end

    # -------------------------------------------------------------------------
    # Register one Output:Meter + EMS chain (sensor -> global var -> program ->
    # PCM -> EMS output var -> Alfalfa OutputVariable) for the given
    # EnergyPlus meter name. All user-facing output is in kWh.
    #
    # The Output:Meter itself is kept (EnergyPlus meters are internally in J)
    # so the EMS sensor has a meter to bind to. Only the kWh-converted
    # custom variable is exported to Alfalfa / the .eso.
    #
    # CRITICAL: out_meter.setName() sets the EnergyPlus meter name, which is
    # the exact string EP uses to look up its internal meter registry.
    # It must be the real meter name (e.g. "Electricity:Facility"), NOT the
    # sanitized identifier. The sanitized name is only used for EMS objects.
    # -------------------------------------------------------------------------
    def add_meter(model, meter_name)
      san = sanitize_ems_name(meter_name)

      # Output:Meter
      out_meter = OpenStudio::Model::OutputMeter.new(model)
      out_meter.setName(meter_name)           # exact EP meter name
      out_meter.setReportingFrequency('Timestep')
      out_meter.setMeterFileOnly(false)       # write to .eso so EMS sensor can read it

      # EMS Sensor (meter-based sensors have no key name)
      sensor_name = san + '_Sensor'
      sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, meter_name)
      sensor.setName(sensor_name)

      # EMS Global Variable (kWh)
      glob_kWh_name = san + '_kWh'
      glob_kWh = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, glob_kWh_name)

      # EMS Program: convert J -> kWh
      prog = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
      prog.setName('Convert_' + san)
      prog.addLine("SET #{glob_kWh_name} = #{sensor_name} / 3600000.0")

      # Program Calling Manager
      pcm = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
      pcm.setName('Run_' + san)
      pcm.setCallingPoint('EndOfSystemTimestepBeforeHVACReporting')
      pcm.addProgram(prog)

      # EMS Output Variable
      ems_out_kWh = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, glob_kWh)
      ems_out_kWh.setName("EMS_#{glob_kWh_name}")
      ems_out_kWh.setUpdateFrequency('Timestep')

      # Alfalfa-readable OutputVariable (kWh)
      ov_kWh = OpenStudio::Model::OutputVariable.new("EMS_#{glob_kWh_name}", model)
      ov_kWh.setName(glob_kWh_name)
      ov_kWh.setReportingFrequency('Timestep')
      ov_kWh.setKeyValue('EMS')
      ov_kWh.setExportToBCVTB(true)
    end

    # =========================================================================
    # OUTPUT VARIABLES — facility-level purchased/surplus/net/produced electricity
    # These are OutputVariables (not meters), key = "Whole Building".
    # Reported in kWh via EMS conversion.
    # =========================================================================
    variables = [
      'Facility Total Purchased Electricity Energy',
      'Facility Total Surplus Electricity Energy',
      'Facility Net Purchased Electricity Energy',
      'Facility Total Produced Electricity Energy'
    ]

    variables.each do |var_name|
      san = sanitize_ems_name(var_name)

      out_var = OpenStudio::Model::OutputVariable.new(var_name, model)
      out_var.setName(san)
      out_var.setReportingFrequency('Timestep')

      sensor_name   = san + '_Sensor'
      glob_kWh_name = san + '_kWh'

      sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, var_name)
      sensor.setName(sensor_name)
      sensor.setKeyName('Whole Building')

      glob_kWh = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, glob_kWh_name)

      prog = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
      prog.setName('Convert_' + san)
      prog.addLine("SET #{glob_kWh_name} = #{sensor_name} / 3600000.0")

      pcm = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
      pcm.setName('Run_' + san)
      pcm.setCallingPoint('EndOfSystemTimestepBeforeHVACReporting')
      pcm.addProgram(prog)

      ems_out_kWh = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, glob_kWh)
      ems_out_kWh.setName("EMS_#{glob_kWh_name}")
      ems_out_kWh.setUpdateFrequency('Timestep')

      ov_kWh = OpenStudio::Model::OutputVariable.new("EMS_#{glob_kWh_name}", model)
      ov_kWh.setName("#{san}_kWh")
      ov_kWh.setReportingFrequency('Timestep')
      ov_kWh.setKeyValue('EMS')
      ov_kWh.setExportToBCVTB(true)
    end

    # =========================================================================
    # OUTPUT METERS
    #
    # The meter list below is derived from the actual .mdd output of ResStock
    # EP 24.2 models. Only meters confirmed present in real model runs are
    # included unconditionally. Fuel-specific meters (gas, oil, propane) and
    # ResStock end-use sub-meters are guarded by model object checks.
    #
    # DO NOT add meters speculatively. An EMS sensor referencing a meter that
    # EnergyPlus never instantiated is a Fatal Severe error.
    # =========================================================================

    # ── Electricity — unconditional (confirmed present in all ResStock models) ─
    # Source: .mdd validated against EP 24.2 ResStock runs
    add_meter(model, 'Electricity:Facility')

    if include_extra_meters
      [
        'Electricity:Building',
        'Electricity:HVAC',
        'Fans:Electricity',
        'Pumps:Electricity',
        'InteriorLights:Electricity',
        'ExteriorLights:Electricity',
        'InteriorEquipment:Electricity',
        'Cooling:Electricity',
        'Heating:Electricity',
        'WaterSystems:Electricity',
      ].each { |m| add_meter(model, m) }
    end

    # ── Electricity — PV/battery systems ──────────────────────────────────────
    # Present when an ElectricLoadCenterDistribution exists (battery, PV, or both).
    # The .mdd confirms: ElectricityProduced:Facility, Cogeneration:Electricity,
    # ElectricityPurchased:Facility, ElectricitySurplusSold:Facility,
    # ElectricityNet:Facility are all instantiated together when ELCD exists.
    if include_extra_meters && model.getElectricLoadCenterDistributions.any?
      runner.registerInfo('PV/battery system detected -- adding electricity production/net meters.')
      [
        'ElectricityProduced:Facility',
        'Cogeneration:Electricity',
        'ElectricityPurchased:Facility',
        'ElectricitySurplusSold:Facility',
        'ElectricityNet:Facility',
      ].each { |m| add_meter(model, m) }
    end

    # ── ResStock end-use sub-meters ───────────────────────────────────────────
    # These are appliance-level breakdowns of InteriorEquipment:Electricity.
    # EnergyPlus creates them via the end-use subcategory on ElectricEquipment
    # objects. Each is guarded by checking the corresponding subcategory.
    # The subcategory string in the meter name must exactly match the
    # endUseSubcategory set on the ElectricEquipment object (case-insensitive
    # in EP meter lookup, but match what ResStock sets).
    #
    # ResStock end-use subcategory -> meter name mapping:
    #   'ceiling fan'         -> 'ceiling fan:InteriorEquipment:Electricity'
    #   'clothes dryer'       -> 'clothes dryer:InteriorEquipment:Electricity'
    #   'clothes washer'      -> 'clothes washer:InteriorEquipment:Electricity'
    #   'cooking range'       -> 'cooking range:InteriorEquipment:Electricity'
    #   'dishwasher'          -> 'dishwasher:InteriorEquipment:Electricity'
    #   'fridge'              -> 'fridge:InteriorEquipment:Electricity'
    #   'mech vent'           -> 'mech vent:InteriorEquipment:Electricity'
    #   'misc plug loads'     -> 'misc plug loads:InteriorEquipment:Electricity'
    #   'whole house fan'     -> 'whole house fan:InteriorEquipment:Electricity'
    # Water heater adjustment is added by ResStock's water heater measure.

    # Collect all end-use subcategories actually present in the model
    electric_subcategories = model.getElectricEquipments
                                  .map { |e| e.endUseSubcategory.downcase.strip }
                                  .to_set

    resstock_end_use_meters = {
      'ceiling fan'       => 'ceiling fan:InteriorEquipment:Electricity',
      'clothes dryer'     => 'clothes dryer:InteriorEquipment:Electricity',
      'clothes washer'    => 'clothes washer:InteriorEquipment:Electricity',
      'cooking range'     => 'cooking range:InteriorEquipment:Electricity',
      'dishwasher'        => 'dishwasher:InteriorEquipment:Electricity',
      'fridge'            => 'fridge:InteriorEquipment:Electricity',
      'mech vent'         => 'mech vent:InteriorEquipment:Electricity',
      'misc plug loads'   => 'misc plug loads:InteriorEquipment:Electricity',
      'whole house fan'   => 'whole house fan:InteriorEquipment:Electricity',
    }

    resstock_end_use_meters.each do |subcategory, meter_name|
      if include_extra_meters && electric_subcategories.include?(subcategory)
        add_meter(model, meter_name)
      end
    end

    # Water heater energy adjustment: added by ResStock water heater measures.
    # The subcategory may be 'water heater energy adjustment' (without number)
    # or 'water heater energy adjustment1' depending on ResStock version.
    # Check for either.
    wh_subcats = electric_subcategories.select { |s| s.start_with?('water heater energy adjustment') }
    if include_extra_meters
      wh_subcats.each do |subcat|
        add_meter(model, "#{subcat}:InteriorEquipment:Electricity")
      end
    end

    # ── Natural Gas ───────────────────────────────────────────────────────────
    has_gas = model.getCoilHeatingGass.any? ||
              model.getBoilerHotWaters.any? { |b| b.fuelType == 'NaturalGas' } ||
              model.getWaterHeaterMixeds.any? { |wh| wh.heaterFuelType == 'NaturalGas' } ||
              model.getGasEquipments.any?

    if include_extra_meters && has_gas
      runner.registerInfo('Natural gas equipment detected -- adding NaturalGas meters.')
      [
        'NaturalGas:Facility',
        'NaturalGas:Building',
        'Heating:NaturalGas',
        'WaterSystems:NaturalGas',
        'InteriorEquipment:NaturalGas',
      ].each { |m| add_meter(model, m) }

      # Exterior gas equipment only if present
      if model.getExteriorFuelEquipments.any? { |e| e.fuelType.downcase == 'naturalgas' }
        add_meter(model, 'ExteriorEquipment:NaturalGas')
      end

      # Gas end-use sub-meters (ResStock sets these via GasEquipment subcategories)
      gas_subcategories = model.getGasEquipments
                               .map { |e| e.endUseSubcategory.downcase.strip }
                               .to_set

      resstock_gas_meters = {
        'clothes dryer'  => 'clothes dryer:InteriorEquipment:NaturalGas',
        'cooking range'  => 'cooking range:InteriorEquipment:NaturalGas',
        'fireplace'      => 'fireplace:InteriorEquipment:NaturalGas',
        'grill'          => 'grill:InteriorEquipment:NaturalGas',
        'lighting'       => 'lighting:InteriorEquipment:NaturalGas',
      }

      resstock_gas_meters.each do |subcategory, meter_name|
        if gas_subcategories.include?(subcategory)
          add_meter(model, meter_name)
        end
      end
    else
      runner.registerInfo('No natural gas equipment -- skipping NaturalGas meters.')
    end

    # ── Fuel Oil #1 ───────────────────────────────────────────────────────────
    has_fueloil = model.getBoilerHotWaters.any? { |b| b.fuelType == 'FuelOilNo1' } ||
                  model.getWaterHeaterMixeds.any? { |wh| wh.heaterFuelType == 'FuelOilNo1' }

    if include_extra_meters && has_fueloil
      runner.registerInfo('Fuel oil equipment detected -- adding FuelOilNo1 meters.')
      [
        'FuelOilNo1:Facility',
        'FuelOilNo1:Building',
        'Heating:FuelOilNo1',
        'WaterSystems:FuelOilNo1',
      ].each { |m| add_meter(model, m) }
    else
      runner.registerInfo('No fuel oil equipment -- skipping FuelOilNo1 meters.')
    end

    # ── Propane ───────────────────────────────────────────────────────────────
    has_propane = model.getBoilerHotWaters.any? { |b| b.fuelType == 'Propane' } ||
                  model.getWaterHeaterMixeds.any? { |wh| wh.heaterFuelType == 'Propane' } ||
                  model.getCoilHeatingGass.any? { |c| c.fuelType == 'Propane' }

    if include_extra_meters && has_propane
      runner.registerInfo('Propane equipment detected -- adding Propane meters.')
      [
        'Propane:Facility',
        'Propane:Building',
        'Heating:Propane',
        'WaterSystems:Propane',
        'InteriorEquipment:Propane',
      ].each { |m| add_meter(model, m) }

      propane_subcategories = model.getOtherEquipments
                                   .select { |e| e.fuelType == 'Propane' }
                                   .map { |e| e.endUseSubcategory.downcase.strip }
                                   .to_set

      resstock_propane_meters = {
        'clothes dryer' => 'clothes dryer:InteriorEquipment:Propane',
        'cooking range' => 'cooking range:InteriorEquipment:Propane',
      }

      resstock_propane_meters.each do |subcategory, meter_name|
        if propane_subcategories.include?(subcategory)
          add_meter(model, meter_name)
        end
      end
    else
      runner.registerInfo('No propane equipment -- skipping Propane meters.')
    end

    # =========================================================================
    # OUTPUT CONTROL FILES
    # =========================================================================
    ocf = model.getOutputControlFiles
    ocf.setOutputCSV(true)
    ocf.setOutputMTR(true)
    ocf.setOutputESO(true)
    ocf.setOutputEIO(false)
    ocf.setOutputTabular(true)
    ocf.setOutputSQLite(false)
    ocf.setOutputJSON(false)
    ocf.setOutputAUDIT(false)
    ocf.setOutputZoneSizing(false)
    ocf.setOutputSystemSizing(false)
    ocf.setOutputDXF(false)
    ocf.setOutputBND(false)
    ocf.setOutputRDD(true)
    ocf.setOutputMDD(true)
    ocf.setOutputMTD(false)
    ocf.setOutputSHD(false)
    ocf.setOutputDFS(false)
    ocf.setOutputGLHE(false)
    ocf.setOutputDelightIn(false)
    ocf.setOutputDelightELdmp(false)
    ocf.setOutputDelightDFdmp(false)
    ocf.setOutputEDD(false)
    ocf.setOutputDBG(false)
    ocf.setOutputPerfLog(false)
    ocf.setOutputSLN(false)
    ocf.setOutputSCI(false)
    ocf.setOutputWRL(false)
    ocf.setOutputScreen(false)
    ocf.setOutputExtShd(false)
    ocf.setOutputTarcog(false)

    return true
  end
end

AddOutputs.new.registerWithApplication
