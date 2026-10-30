# *********************************************************************************
# URBANopt™, Copyright (c) 2019-2022, Alliance for Sustainable Energy, LLC, and other
# contributors. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.
#
# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
# *********************************************************************************

require 'urbanopt/reporting'
require 'openstudio/common_measures'
require 'openstudio/model_articulation'
require 'openstudio/ee_measures'
require 'openstudio/calibration'

require_relative 'Baseline'
require_relative 'Control'

require 'json'

module URBANopt
  module Scenario
    class ElectrificationLowMapper < ControlMapper
      def create_osw(scenario, features, feature_names)
        osw = super(scenario, features, feature_names)

        feature = features[0]
        building_type = feature.building_type
        template = feature.template

        # Residential Measures
        if residential_building_types.include? building_type
          args = {}
          osw[:steps].each do |step|
            next if step[:measure_dir_name] != 'BuildResidentialModel'

            step[:arguments].each do |arg_name, arg_val|
              args[arg_name] = arg_val
            end
          end

          system_type = feature.system_type
          number_of_bedrooms = feature.number_of_bedrooms
          if defined?(feature.lighting_tech_type) 
            lighting_tech_type = feature.lighting_tech_type
          else
            lighting_tech_type = nil
          end
          attic_type = feature.attic_type

          puts"##### Reporting Electrification Changes Made"

          # HVAC
          heat_pump_heating_efficiency = args[:heat_pump_heating_efficiency]
          args[:heating_system_type] ='none'	
          args[:heating_system_heating_efficiency] ='0'	
          args[:heating_system_heating_capacity] ='auto'	
          args[:heating_system_fraction_heat_load_served] ='1'	
          args[:heat_pump_heating_efficiency_type] ='HSPF'	
          args[:heat_pump_cooling_efficiency_type] ='SEER'	
          args[:heat_pump_heating_capacity] ='auto'	
          args[:heat_pump_heating_capacity_17_f] ='auto'	
          args[:heat_pump_fraction_heat_load_served] ='1'	
          args[:heat_pump_cooling_capacity] ='auto'	
          args[:heat_pump_fraction_cool_load_served] ='1'	
          args[:heat_pump_backup_type] ='integrated'	
          args[:heat_pump_backup_fuel] ='electricity'	
          args[:heat_pump_backup_heating_efficiency] ='1'	
          args[:heat_pump_backup_heating_capacity] ='auto'	
          args[:cooling_system_type] ='none'	
          #args[:heat_pump_capacity_retention_fraction] ='0.50'	
          #args[:heat_pump_capacity_retention_temp] ='-15'	
          #args[:heating_system_has_flue_or_chimney] ='auto'	
          if heat_pump_heating_efficiency.to_f <= 12 # If system HSPF (heating seasonal performance factor) is within margin
            if system_type.include?("boiler")   # no ducts
              # HVAC Heating Efficiency	"MSHP, SEER 29.3, 14 HSPF, Max Load"
              args[:heat_pump_type] ='mini-split'
              args[:heat_pump_heating_efficiency] = '14'	
              args[:heat_pump_cooling_efficiency] = '29.3'
              #args[:heat_pump_sizing_methodology] = 'MaxLoad'
              puts"##### HVAC_heater changed to type:mini-split and heating_efficiency:14 and cooling_efficiency:29.3"
            elsif system_type.include?("furnace")  # ducts
              # HVAC Heating Efficiency	"ASHP, SEER 24, 13 HSPF"
              args[:heat_pump_type] ='air-to-air'
              args[:heat_pump_heating_efficiency] = '13'	
              args[:heat_pump_cooling_efficiency] = '24'
              #args[:heat_pump_sizing_methodology] = 'ACCA'
              puts"##### HVAC_heater changed to type:mini-split and heating_efficiency:13 and cooling_efficiency:24"
            else # Same as furnace option
              # HVAC Heating Efficiency	"ASHP, SEER 24, 13 HSPF"
              args[:heat_pump_type] ='air-to-air'
              args[:heat_pump_heating_efficiency] = '13'
              args[:heat_pump_cooling_efficiency] = '24'
              #args[:heat_pump_sizing_methodology] = 'ACCA'
              puts"##### HVAC_heater changed to type:mini-split and heating_efficiency:13 and cooling_efficiency:24"
            end
          end

          # WATER HEATER
          args[:water_heater_type] = 'heat pump water heater' 
          args[:water_heater_fuel_type] = 'electricity' 
          args[:water_heater_location] = 'auto'
          args[:water_heater_efficiency_type] = 'UniformEnergyFactor' 
          args[:water_heater_recovery_efficiency] = '0.5'
          args[:water_heater_standby_loss] = '0' 
          args[:water_heater_jacket_rvalue] = '0' 
          args[:water_heater_setpoint_temperature] = '125' 
          args[:water_heater_heating_capacity] = 'auto' 
          #args[:water_heater_has_flue_or_chimney] = 'auto' 
          args[:water_heater_num_units_served] = '1' 
          if number_of_bedrooms <= 3
            # Water Heater Efficiency	"Electric Heat Pump, 50 gal, 3.45 UEF"
            args[:water_heater_tank_volume] = '50' 
            args[:water_heater_efficiency] = '3.45' 
            puts"##### water_heater changed to volume:50 and efficiency:3.45"			
          elsif number_of_bedrooms == 4
            # Water Heater Efficiency	"Electric Heat Pump, 66 gal, 3.35 UEF"
            args[:water_heater_tank_volume] = '66' 
            args[:water_heater_efficiency] = '3.35' 
            puts"##### water_heater changed to volume:66 and efficiency:3.35"
          elsif number_of_bedrooms >= 5
            # Water Heater Efficiency	"Electric Heat Pump, 80 gal, 3.45 UEF"
            args[:water_heater_tank_volume] = '80' 
            args[:water_heater_efficiency] = '3.45' 
            puts"##### water_heater changed to volume:80 and efficiency:3.45"
          end

          # COOKING RANGE
          # Cooking Range	"Electric, 100% Usage"
          #args[:cooking_range_oven_present] ='true'	
          args[:cooking_range_oven_location] ='auto'	
          args[:cooking_range_oven_fuel_type] ='electricity'	
          args[:cooking_range_oven_is_induction] ='false'	
          args[:cooking_range_oven_usage_multiplier] ='1.0'		

          # CLOTHES DRYER
          # Clothes Dryer	"Electric, 100% Usage"
          #args[:clothes_dryer_present] ='true'	
          args[:clothes_dryer_location] ='auto'	
          args[:clothes_dryer_fuel_type] ='electricity'	
          args[:clothes_dryer_efficiency_type] ='CombinedEnergyFactor'	
          args[:clothes_dryer_efficiency] ='2.70'	
          args[:clothes_dryer_vented_flow_rate] ='auto'	
          args[:clothes_dryer_usage_multiplier] ='1.0'	

          # LIGHTING
          if lighting_tech_type != nil && !lighting_tech_type.include?("led")
            # Option: Lighting	100% LED
            args[:lighting_present] = 'true'	
            args[:lighting_interior_fraction_cfl] = '0'	
            args[:lighting_interior_fraction_lfl] = '0'	
            args[:lighting_interior_fraction_led] = '1'	
            args[:lighting_exterior_fraction_cfl] = '0'	
            args[:lighting_exterior_fraction_lfl] = '0'	
            args[:lighting_exterior_fraction_led] = '1'	
            args[:lighting_garage_fraction_cfl] = '0'	
            args[:lighting_garage_fraction_lfl] = '0'	
            args[:lighting_garage_fraction_led] = '1'		
            puts"##### lighting changed to 100% LED"			
          end											

          # INFILTRATION
          air_leakage_value_old = args[:air_leakage_value]
          if air_leakage_value_old.to_f >= 15
            # Option: Infiltration Reduction 30%	
            args[:air_leakage_value] = Float(args[:air_leakage_value]) * 0.7 # 30% decrease
            puts"##### air_leakage_value changed from #{air_leakage_value_old} to #{args[:air_leakage_value]}"
          end

          # WINDOWS
          window_ufactor_old = args[:window_ufactor]
          if window_ufactor_old.to_f >= 0.8
            # Use minimum code compliance (simulating replacement of single pane window with new double pane)
            args[:window_ufactor] = 0.35
            puts"##### window_ufactor changed from #{window_ufactor_old} to #{args[:window_ufactor]}"
          elsif window_ufactor_old.to_f < 0.8 and window_ufactor_old.to_f >= 0.4
            # Use interpolation formula to find U-factor improvement
            percimp = Float(args[:window_ufactor])*33.345 + 4.99
            args[:window_ufactor] = Float(args[:window_ufactor])*(1-percimp/100)
            puts"##### window_ufactor changed from #{window_ufactor_old} to #{args[:window_ufactor]}"
          end

          args.each do |arg_name, arg_val|
            OpenStudio::Extension.set_measure_argument(osw, 'BuildResidentialModel', arg_name, arg_val)
          end
		  
		  ##AA added 1/17
		  OpenStudio::Extension.set_measure_argument(osw, 'ithaca_add_reporting_variables', '__SKIP__', false)
		  
		  ##AA added 1/17 
		  OpenStudio::Extension.set_measure_argument(osw, 'creat_csv_output', '__SKIP__', false)
		  OpenStudio::Extension.set_measure_argument(osw, 'creat_csv_output', 'reporting_frequency', 'Zone Timestep')

        # Commercial Buildings
        elsif commercial_building_types.include? building_type
          # Add Roof Top Unit Heat Pump
          #OpenStudio::Extension.set_measure_argument(osw, 'add_heat_pump_rtu', '__SKIP__', false)
          #OpenStudio::Extension.set_measure_argument(osw, 'add_heat_pump_rtu', 'backup_ht_fuel_scheme', 'electric_resistance_backup')
        
          # add_hpwh
          #OpenStudio::Extension.set_measure_argument(osw, 'add_hpwh', '__SKIP__', false)
          #OpenStudio::Extension.set_measure_argument(osw, 'add_hpwh', 'vol', 2)

          # ReduceSpaceInfiltrationByPercentage
          #OpenStudio::Extension.set_measure_argument(osw, 'ReduceSpaceInfiltrationByPercentage', '__SKIP__', false)
          #OpenStudio::Extension.set_measure_argument(osw, 'ReduceSpaceInfiltrationByPercentage', 'space_infiltration_reduction_percent', 50.0)

          # IncreaseInsulationRValueForRoofs
          #OpenStudio::Extension.set_measure_argument(osw, 'IncreaseInsulationRValueForRoofs', '__SKIP__', false)
          #OpenStudio::Extension.set_measure_argument(osw, 'IncreaseInsulationRValueForRoofs', 'r_value', 60.0)

          # ReduceLightingLoadsByPercentage
          #OpenStudio::Extension.set_measure_argument(osw, 'ReduceLightingLoadsByPercentage', '__SKIP__', false)
          #OpenStudio::Extension.set_measure_argument(osw, 'ReduceLightingLoadsByPercentage', 'lighting_power_reduction_percent', 30.0)

          # Appliances: Build our own measure
        
        end

        return osw
      end
    end
  end
end
