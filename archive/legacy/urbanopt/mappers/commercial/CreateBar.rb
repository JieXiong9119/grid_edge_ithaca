# *********************************************************************************
# URBANopt™, Copyright (c) 2019-2021, Alliance for Sustainable Energy, LLC, and other
# contributors. All rights reserved.

# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:

# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.

# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.

# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.

# Redistribution of this software, without modification, must refer to the software
# by the same designation. Redistribution of a modified version of this software
# (i) may not refer to the modified version by the same designation, or by any
# confusingly similar designation, and (ii) must refer to the underlying software
# originally provided by Alliance as “URBANopt”. Except to comply with the foregoing,
# the term “URBANopt”, or any confusingly similar designation may not be used to
# refer to any modified version of this software or any modified version of the
# underlying software originally provided by Alliance without the prior written
# consent of Alliance.

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

require 'json'

module URBANopt
  module Scenario
    class CreateBarMapper < SimulationMapperBase
      # class level variables
      @@instance_lock = Mutex.new
      @@osw = nil
      @@geometry = nil

      def initialize
        # do initialization of class variables in thread safe way
        @@instance_lock.synchronize do
          if @@osw.nil?

            # load the OSW for this class
            osw_path = File.join(File.dirname(__FILE__), 'createbar_workflow.osw')
            File.open(osw_path, 'r') do |file|
              @@osw = JSON.parse(file.read, symbolize_names: true)
            end

            # add any paths local to the project
            @@osw[:measure_paths] << File.join(File.dirname(__FILE__), '../measures/')
            @@osw[:measure_paths] << File.join(File.dirname(__FILE__), '../resources/hpxml-measures')
            @@osw[:file_paths] << File.join(File.dirname(__FILE__), '../weather/')

            # configures OSW with extension gem paths for measures and files, all extension gems must be
            # required before this
            @@osw = OpenStudio::Extension.configure_osw(@@osw)
          end
        end
      end

      def lookup_building_type(building_type, template, footprint_area, number_of_stories)
        if template.include? "DEER"
          case building_type
          when "Education"
            return "EPr"
          when "Enclosed mall"
            return "RtL"
          when "Food sales"
            return "RSD"
          when "Food service"
            return "RSD"
          when "Inpatient health care"
            return "Nrs"
          when "Laboratory"
            return "Hsp"
          when "Lodging"
            return "Htl"
          when "Mixed use"
            return "ECC"
          when "Mobile Home"
            return "DMo"
          when "Multifamily (2 to 4 units)"
            return "MFm"
          when "Multifamily (5 or more units)"
            return "MFm"
          when "Nonrefrigerated warehouse"
            return "SUn"
          when "Nursing"
            return "Nrs"
          when "Office"
            if footprint_area
              if footprint_area.to_f > 100000
                return "OfL"
              else
                return "OfS"
              end
            else
              raise "footprint_area required to map office building type"
            end
          when "Outpatient health care"
            return "Nrs"
          when "Public assembly"
            return "Asm"
          when "Public order and safety"
            return "Asm"
          when "Refrigerated warehouse"
            return "WRf"
          when "Religious worship"
            return "Asm"
          when "Retail other than mall"
            return "RtS"
          when "Service"
            return "MLI"
          when "Single-Family"
            return "MFm"
          when "Strip shopping mall"
            return "RtL"
          when "Vacant"
            return "SUn"
          else
           raise "building type #{building_type} cannot be mapped to a DEER building type"
          end

        else
          # default: ASHRAE
          case building_type
          when "Education"
            return 'SecondarySchool'
          when "Enclosed mall"
            return "RetailStripmall"
          when "Food sales"
            return "FullServiceRestaurant"
          when "Food service"
            return "FullServiceRestaurant"
          when "Inpatient health care"
            return "Hospital"
          when "Laboratory"
            return "Laboratory"
          when "Lodging"
            if number_of_stories
              if number_of_stories.to_i > 3
                return "LargeHotel"
              else
                return "SmallHotel"
              end
            end
            return "LargeHotel"
          when "Mixed use"
            return "Mixed use"
          when "Mobile Home"
            return "MidriseApartment"
          when "Multifamily (2 to 4 units)"
            return "MidriseApartment"
          when "Multifamily (5 or more units)"
            return "MidriseApartment"
          when "Nonrefrigerated warehouse"
            return "Warehouse"
          when "Nursing"
            return "Outpatient"
          when "Office"
            if footprint_area
              if footprint_area.to_f < 20000
                value = "SmallOffice"
              elsif footprint_area.to_f > 100000
                value = "LargeOffice"
              else
                value = "MediumOffice"
              end
            else
              raise "Floor area required to map office building type"
            end
          when "Outpatient health care"
            return "Outpatient"
          when "Public assembly"
            return "MediumOffice"
          when "Public order and safety"
            return "MediumOffice"
          when "Refrigerated warehouse"
            return "Warehouse"
          when "Religious worship"
            return "MediumOffice"
          when "Retail other than mall"
            return "RetailStandalone"
          when "Service"
            return "MediumOffice"
          when "Single-Family"
            return "MidriseApartment"
          when "Strip shopping mall"
            return "RetailStripmall"
          when "Vacant"
            return "Warehouse"
          else
            raise "building type #{building_type} cannot be mapped to an ASHRAE building type"
          end
        end
      end


      def lookup_template_by_year_built(template, year_built)
        if template.include? 'DEER'
          if year_built <= 1996
            return 'DEER 1985'
          elsif year_built <= 2003
            return 'DEER 1996'
          elsif year_built <= 2007
            return 'DEER 2003'
          elsif year_built <= 2011
            return 'DEER 2007'
          elsif year_built <= 2014
            return 'DEER 2011'
          elsif year_built <= 2015
            return 'DEER 2014'
          elsif year_built <= 2017
            return 'DEER 2015'
          elsif year_built <= 2020
            return 'DEER 2017'
          else
            return 'DEER 2020'
          end
        else
          # ASHRAE
          if year_built < 1980
            return 'DOE Ref Pre-1980'
          elsif year_built <= 2004
            return 'DOE Ref 1980-2004'
          elsif year_built <= 2007
            return '90.1-2004'
          elsif year_built <= 2010
            return '90.1-2007'
          elsif year_built <= 2013
            return '90.1-2010'
          else
            return '90.1-2013'
          end
        end
      end


      def residential_building_types
        return [
          'Single-Family Detached',
          'Single-Family Attached',
          'Multifamily'
        ]
      end

      def commercial_building_types
        return [
          'Vacant',
          'Office',
          'Laboratory',
          'Nonrefrigerated warehouse',
          'Food sales',
          'Public order and safety',
          'Outpatient health care',
          'Refrigerated warehouse',
          'Religious worship',
          'Public assembly',
          'Education',
          'Food service',
          'Inpatient health care',
          'Nursing',
          'Lodging',          
          'Strip shopping mall',
          'Enclosed mall',
          'Retail other than mall',
          'Service',
          'Uncovered Parking',
          'Covered Parking',
          'Mixed use',
          'Multifamily (2 to 4 units)',
          'Multifamily (5 or more units)',
          'Single-Family'
        ]
      end

      def get_arg_default(arg)
        case arg.type.valueName.downcase
        when 'boolean'
          return arg.defaultValueAsBool
        when 'double'
          return arg.defaultValueAsDouble
        when 'integer'
          return arg.defaultValueAsInteger
        when 'string'
          return arg.defaultValueAsString
        when 'choice'
          return arg.defaultValueAsString
        end
      end

      def get_lookup_tsv(args, filepath)
        rows = []
        headers = []
        units = []
        CSV.foreach(filepath, { :col_sep => "\t" }) do |row|
          if headers.empty?
            row.each do |header|
              next if header == 'Source'
              if args.keys.include?(header.gsub('Dependency=', '').to_sym)
                header = header.gsub('Dependency=', '')
              end
              unless header.include?('Dependency=')
                header = header.to_sym
              end
              headers << header
            end
            next
          elsif units.empty?
            row.each do |unit|
              units << unit
            end
            next
          end
          if headers.length != row.length
            row = row[0..-2] # leave out Source column
          end
          rows << headers.zip(row).to_h
        end
        return rows
      end


      def get_lookup_row(args, rows, template_vals)
        rows.each do |row|
          if row.keys.include?('Dependency=Climate Zone')
            next if row['Dependency=Climate Zone'] != template_vals[:climate_zone]
          end
          if row.keys.include?('Dependency=IECC Year')
            next if row['Dependency=IECC Year'] != template_vals[:iecc_year]
          end
          if row.keys.include?('Dependency=Template Month')
            next if row['Dependency=Template Month'] != template_vals[:t_month]
          end
          if row.keys.include?('Dependency=Template Year')
            next if row['Dependency=Template Year'] != template_vals[:t_year]
          end
          row.delete('Dependency=Climate Zone')
          row.delete('Dependency=IECC Year')
          row.delete('Dependency=Template Month')
          row.delete('Dependency=Template Year')

          row.each do |k, v|
            next unless v.nil?

            row.delete(k)
          end

          intersection = args.keys & row.keys
          return row if intersection.empty? # found the correct row

          skip = false
          intersection.each do |k|
            if args[k] != row[k]
              skip = true
            end
          end

          return row unless skip
        end
        return nil
      end

      def get_climate_zone_iecc(epw)
        headers = CSV.open(epw, 'r') { |csv| csv.first }
        wmo = headers[5]
        zones_csv = File.join(File.dirname(__FILE__), '../resources/hpxml-measures/HPXMLtoOpenStudio/resources/data_climate_zones.csv')
        CSV.foreach(zones_csv) do |row|
          if row[0].to_s == wmo.to_s
            return row[6].to_s
          end
        end
      end

      def create_osw(scenario, features, feature_names)
        if features.size != 1
          raise 'TestMapper1 currently cannot simulate more than one feature'
        end
        feature = features[0]
        feature_id = feature.id
        feature_type = feature.type
        # take the centroid of the vertices as the location of the building
        feature_vertices_coordinates = feature.feature_json[:geometry][:coordinates][0]
        feature_location = feature.find_feature_center(feature_vertices_coordinates).to_s
        
        feature_name = feature.name
		##AA added
		lighting_tech_type=feature.lighting_tech_type
		wkdy_bpr=feature.wkday_bpr_light
		modify_wkdy_bpr=feature.modify_wkdy_light_bpr
		modify_wknd_bpr=feature.modify_wknd_light_bpr
		wknd_bpr=feature.wknd_bpr_light
		comstock_const_vintage=feature.comstock_const_vintage
		plug_vintage=feature.plug_vintage
		modify_wkday_plug_bpr=feature.modify_wkdy_plug_bpr
		modify_wknd_plug_bpr=feature.modify_wknd_plug_bpr
		wkday_plug_bpr=feature.wkday_bpr_plug
		wknd_plug_bpr=feature.wknd_bpr_plug
		swh_vintage=feature.swh_vintage
		hvac_vintage=feature.hvac_vintage
		ext_lighting_vintage='ComStock 90.1-2019'
        
        if feature_names.size == 1
          feature_name = feature_names[0]
        end

        # deep clone of @@osw before we configure it
        osw = Marshal.load(Marshal.dump(@@osw))

        # now we have the feature, we can look up its properties and set arguments in the OSW
        osw[:name] = feature_name
        osw[:description] = feature_name

        if feature_type == 'Building'

          # set_run_period
          begin
            timesteps_per_hour = feature.timesteps_per_hour
            if timesteps_per_hour
              OpenStudio::Extension.set_measure_argument(osw, 'set_run_period', 'timesteps_per_hour', timesteps_per_hour)
            end
          rescue StandardError
          end
          begin
            begin_date = feature.begin_date
            if begin_date
              # check date-only YYYY-MM-DD
              if begin_date.length > 10
                begin_date = begin_date[0, 10]
              end
              OpenStudio::Extension.set_measure_argument(osw, 'set_run_period', 'begin_date', begin_date)
            end
          rescue StandardError
          end
          begin
            end_date = feature.end_date
            if end_date
              # check date-only YYYY-MM-DD
              if end_date.length > 10
                end_date = end_date[0, 10]
              end
              OpenStudio::Extension.set_measure_argument(osw, 'set_run_period', 'end_date', end_date)
            end
          rescue StandardError
          end

          # convert to hash
          building_hash = feature.to_hash
          # check for detailed model filename
          if building_hash.key?(:detailed_model_filename)
            detailed_model_filename = building_hash[:detailed_model_filename]
            osw[:file_paths] << File.join(File.dirname(__FILE__), '../osm_building/')
            osw[:seed_file] = detailed_model_filename

            # skip create_bar measure with detailed models:
            OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', '__SKIP__', true)

            # skip create typical building measure with detailed models:
            OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', '__SKIP__', true)


            # skip PMV measure with detailed models:
            OpenStudio::Extension.set_measure_argument(osw, 'PredictedMeanVote', '__SKIP__', true)

          # in case detailed model filename is not present
          else

            building_type_1 = building_hash[:building_type]

            # lookup/map building type
            number_of_stories = building_hash[:number_of_stories]
            if building_hash.key?(:number_of_stories_above_ground)
              number_of_stories_above_ground = building_hash[:number_of_stories_above_ground]
              number_of_stories_below_ground = number_of_stories - number_of_stories_above_ground
            else
              number_of_stories_above_ground = number_of_stories
              number_of_stories_below_ground = 0
            end
            template = building_hash.key?(:template) ? building_hash[:template] : nil
            footprint_area = building_hash[:footprint_area]

            mapped_building_type_1 = lookup_building_type(building_type_1, template, footprint_area, number_of_stories)

            # process Mixed Use (for create_bar measure)
            if building_type_1 == 'Mixed use'
              # map mixed use types
              running_fraction = 0
              mixed_type_1 = building_hash[:mixed_type_1]
              mixed_type_2 = building_hash.key?(:mixed_type_2) ? building_hash[:mixed_type_2] : nil
              unless mixed_type_2.nil?
                mixed_type_2_percentage = building_hash[:mixed_type_2_percentage]
                mixed_type_2_fract_bldg_area = mixed_type_2_percentage * 0.01
                running_fraction += mixed_type_2_fract_bldg_area
              end

              mixed_type_3 = building_hash.key?(:mixed_type_3) ? building_hash[:mixed_type_3] : nil
              unless mixed_type_3.nil?
                mixed_type_3_percentage = building_hash[:mixed_type_3_percentage]
                mixed_type_3_fract_bldg_area = mixed_type_3_percentage * 0.01
                running_fraction += mixed_type_3_fract_bldg_area
              end

              mixed_type_4 = building_hash.key?(:mixed_type_4) ? building_hash[:mixed_type_4] : nil
              unless mixed_type_4.nil?
                mixed_type_4_percentage = building_hash[:mixed_type_4_percentage]
                mixed_type_4_fract_bldg_area = mixed_type_4_percentage * 0.01
                running_fraction += mixed_type_4_fract_bldg_area
              end

              # potentially calculate from other inputs
              mixed_type_1_fract_bldg_area = building_hash.key?(:mixed_type_1_percentage) ? building_hash[:mixed_type_1_percentage] : (1 - running_fraction)

              # lookup mixed_use types
              footprint_1 = footprint_area * mixed_type_1_fract_bldg_area
              openstudio_mixed_type_1 = lookup_building_type(mixed_type_1, template, footprint_1, number_of_stories)
              unless mixed_type_2.nil?
                footprint_2 = footprint_area * mixed_type_2_fract_bldg_area
                openstudio_mixed_type_2 = lookup_building_type(mixed_type_2, template, footprint_2, number_of_stories)
              end
              unless mixed_type_3.nil?
                footprint_3 = footprint_area * mixed_type_3_fract_bldg_area
                openstudio_mixed_type_3 = lookup_building_type(mixed_type_3, template, footprint_3, number_of_stories)
              end
              unless mixed_type_4.nil?
                footprint_4 = footprint_area * mixed_type_4_fract_bldg_area
                openstudio_mixed_type_4 = lookup_building_type(mixed_type_4, template, footprint_4, number_of_stories)
              end
            end

            floor_height = 10
			##AA added
			#read in lighting tech type
			lighting_tech_type=feature.lighting_tech_type #building_hash[:lighting_tech_type]
            # Map system type to openstudio system types
            # TODO: Map all system types
            if building_hash.key?(:system_type)
              system_type = building_hash[:system_type]
              case system_type
              when 'Fan coil district hot and chilled water'
                system_type = 'Fan coil district chilled water with district hot water'
              when 'Fan coil air-cooled chiller and boiler'
                system_type = 'Fan coil air-cooled chiller with boiler'
              when 'VAV with gas reheat'
                system_type = 'VAV air-cooled chiller with gas boiler reheat'
              end
            else
              system_type = 'Inferred'
            end

            def time_mapping(time)
              hour = time.split(':')[0]
              minute = time.split(':')[1]
              fraction = minute.to_f / 60
              fraction_roundup = fraction.round(2)
              minute_fraction = fraction_roundup.to_s.split('.')[1]
              new_time = [hour, minute_fraction].join('.')
              return new_time
            end

            # ChangeBuildingLocation

            # cec climate zone takes precedence
            cec_found = false
            begin
              cec_climate_zone = feature.cec_climate_zone
              if !cec_climate_zone.empty?
                cec_climate_zone = 'T24-CEC' + cec_climate_zone
                OpenStudio::Extension.set_measure_argument(osw, 'ChangeBuildingLocation', 'climate_zone', cec_climate_zone)
                cec_found = true
                # Temporary fix for CEC climate zone:
                cec_modified_zone = 'CEC ' + cec_climate_zone
                OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'climate_zone', cec_modified_zone)
                OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'climate_zone', cec_modified_zone, 'create_typical_building_from_model')
              end
            rescue StandardError
            end
            if !cec_found
              begin
                climate_zone = feature.climate_zone
                if !climate_zone.empty?
                  climate_zone = 'ASHRAE 169-2013-' + climate_zone
                  OpenStudio::Extension.set_measure_argument(osw, 'ChangeBuildingLocation', 'climate_zone', climate_zone)
               end
              rescue StandardError
              end
            end

            # set weather file
            begin
              weather_filename = feature.weather_filename
              if !feature.weather_filename.nil? && !feature.weather_filename.empty?
                OpenStudio::Extension.set_measure_argument(osw, 'ChangeBuildingLocation', 'weather_file_name', weather_filename)
                puts "Setting weather_file_name to #{weather_filename} as specified in the FeatureFile"
              end
            rescue StandardError
              puts 'No weather_file specified on feature'
              epw_file_path = Dir.glob(File.join(File.dirname(__FILE__), '../weather/*.epw'))[0]
              if !epw_file_path.nil? && !epw_file_path.empty?
                epw_file_name = File.basename(epw_file_path)
                OpenStudio::Extension.set_measure_argument(osw, 'ChangeBuildingLocation', 'weather_file_name', epw_file_name)
                puts "Setting weather_file_name to first epw file found in the weather folder: #{epw_file_name}"
              else
                puts 'NO WEATHER FILES SPECIFIED...SIMULATIONS MAY FAIL'
              end
            end

            # geojson schema doesn't have modify_wkdy_op_hrs and modify_wknd_op_hrs checking for both start and duration to set to true in osw
            weekday_flag = 0 # set modify arg to true of this gets to 2
            weekend_flag = 0 # set modify arg to true of this gets to 2

            # set weekday start time
            begin
              weekday_start_time = feature.weekday_start_time
              if !feature.weekday_start_time.empty?
                new_weekday_start_time = time_mapping(weekday_start_time)
                OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'wkdy_op_hrs_start_time', new_weekday_start_time, 'create_typical_building_from_model')
                weekday_flag += 1
              end
            rescue StandardError
            end

            # set weekday duration
            begin
              weekday_duration = feature.weekday_duration
              if !feature.weekday_duration.empty?
                new_weekday_duration = time_mapping(weekday_duration)
                OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'wkdy_op_hrs_duration', new_weekday_duration, 'create_typical_building_from_model')
                weekday_flag += 1
              end
            rescue StandardError
            end

            # set weekday modify 
            begin
              if weekday_flag == 2
                OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'modify_wknd_op_hrs', true, 'create_typical_building_from_model')
              end
            rescue StandardError
            end

            # set weekend start time
            begin
              weekend_start_time = feature.weekend_start_time
              if !feature.weekend_start_time.empty?
                new_weekend_start_time = time_mapping(weekend_start_time)
                OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'wknd_op_hrs_start_time', new_weekend_start_time, 'create_typical_building_from_model')
                weekend_flag += 1
              end
            rescue StandardError
            end

            # set weekend duration
            begin
              weekend_duration = feature.weekend_duration
              if !feature.weekend_duration.empty?
                new_weekend_duration = time_mapping(weekend_duration)
                OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'wknd_op_hrs_duration', new_weekend_duration, 'create_typical_building_from_model')
                weekend_flag += 1
              end
            rescue StandardError
            end

            # set weekday modify 
            begin
              if weekend_flag == 2
                OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'modify_wkdy_op_hrs', true, 'create_typical_building_from_model')
              end
            rescue StandardError
            end

            # template
            begin
              new_template = nil
              template = feature.template

              # can we override template with year_built info? (keeping same template family)
              if building_hash.key?(:year_built) && !building_hash[:year_built].nil? && !feature.template.empty?
                new_template = lookup_template_by_year_built(template, year_built)
              elsif !feature.template.empty?
                new_template = template
              end

              if new_template
                OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'template', new_template)
                OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'template', new_template, 'create_typical_building_from_model')
              end
            rescue StandardError
            end

            # TODO: surface_elevation has no current mapping
            # TODO: tariff_filename has no current mapping

            # create a bar building, will have spaces tagged with individual space types given the
            # input building types

            OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'single_floor_area', footprint_area)
            OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'floor_height', floor_height)
            OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'num_stories_above_grade', number_of_stories_above_ground)
            OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'num_stories_below_grade', number_of_stories_below_ground)

            OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_a', mapped_building_type_1)

            if building_type_1 == 'Mixed use'

              OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_a', openstudio_mixed_type_1)

              unless mixed_type_2.nil?
                OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_b', openstudio_mixed_type_2)
                OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_b_fract_bldg_area', mixed_type_2_fract_bldg_area)
              end
              unless mixed_type_3.nil?
                OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_c', openstudio_mixed_type_3)
                OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_c_fract_bldg_area', mixed_type_3_fract_bldg_area)
              end
              unless mixed_type_4.nil?
                OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_d', openstudio_mixed_type_4)
                OpenStudio::Extension.set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_d_fract_bldg_area', mixed_type_4_fract_bldg_area)
              end
            end

            # calling create typical building will create space types and assign HVAC systems
            OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', '__SKIP__', false)
            OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'system_type', system_type, 'create_typical_building_from_model')

            # calling create typical building the first time will create space types
            #OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', '__SKIP__', false)
            #OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'add_hvac', false, 'create_typical_building_from_model 1')

		    #apply removal of small spaces for retail buildings 
			if building_type_1=='Retail other than mall' or building_type_1=='Mixed use' #can modify this later on to look at retail as one of the types 
				OpenStudio::Extension.set_measure_argument(osw, 'remove_small_spaces', '__SKIP__', false)

            end

            # activate prototype_space_type_assignment
            OpenStudio::Extension.set_measure_argument(osw, 'prototype_space_type_assignment', '__SKIP__', false)
			
			# if ! building_type_1 == 'Retail' #retail buildings don't have DHW systems in these models 
           # # Add Roof Top Unit Heat Pump
				# OpenStudio::Extension.set_measure_argument(osw, 'add_heat_pump_rtu', '__SKIP__', false)
				# OpenStudio::Extension.set_measure_argument(osw, 'add_heat_pump_rtu', 'backup_ht_fuel_scheme', 'electric_resistance_backup')
		    # end 
			
			#where measure was originally 12/7 
			#OpenStudio::Extension.set_measure_argument(osw, 'add_hpwh', '__SKIP__', false)
			
			
			#measure was here til 12/7 
			# if commercial_building_types.include? building_type_1
           # # Add Roof Top Unit Heat Pump
				# OpenStudio::Extension.set_measure_argument(osw, 'add_heat_pump_rtu', '__SKIP__', false)
				# OpenStudio::Extension.set_measure_argument(osw, 'add_heat_pump_rtu', 'backup_ht_fuel_scheme', 'electric_resistance_backup')
		    # end 

            # activate set_interior_lighting_technology
            OpenStudio::Extension.set_measure_argument(osw, 'set_interior_lighting_technology', '__SKIP__', false)
            OpenStudio::Extension.set_measure_argument(osw, 'set_interior_lighting_technology', 'lighting_generation', lighting_tech_type)

            # activate set_interior_lighting_bpr'
            OpenStudio::Extension.set_measure_argument(osw, 'set_interior_lighting_bpr', '__SKIP__', false)
            OpenStudio::Extension.set_measure_argument(osw, 'set_interior_lighting_bpr', 'modify_wkdy_bpr', modify_wkdy_bpr)
            OpenStudio::Extension.set_measure_argument(osw, 'set_interior_lighting_bpr', 'wkdy_bpr', wkdy_bpr)
            OpenStudio::Extension.set_measure_argument(osw, 'set_interior_lighting_bpr', 'modify_wknd_bpr', modify_wknd_bpr)
            OpenStudio::Extension.set_measure_argument(osw, 'set_interior_lighting_bpr', 'wknd_bpr', wknd_bpr)
			
			#set interior equipment template 
			OpenStudio::Extension.set_measure_argument(osw, 'set_interior_equipment_template', '__SKIP__', false)
			OpenStudio::Extension.set_measure_argument(osw, 'set_interior_equipment_template', 'as_constructed_template', comstock_const_vintage)
			OpenStudio::Extension.set_measure_argument(osw, 'set_interior_equipment_template', 'template', plug_vintage)
			OpenStudio::Extension.set_measure_argument(osw, 'set_interior_equipment_template', 'climate_zone', 'ASHRAE 169-2013-6A')
			
			#set interior equipment bpr 
			OpenStudio::Extension.set_measure_argument(osw, 'set_electric_equipment_bpr', '__SKIP__', false)
            OpenStudio::Extension.set_measure_argument(osw, 'set_electric_equipment_bpr', 'modify_wkdy_bpr', modify_wkday_plug_bpr)
            OpenStudio::Extension.set_measure_argument(osw, 'set_electric_equipment_bpr', 'wkdy_bpr', wkday_plug_bpr)
            OpenStudio::Extension.set_measure_argument(osw, 'set_electric_equipment_bpr', 'modify_wknd_bpr', modify_wknd_plug_bpr)
            OpenStudio::Extension.set_measure_argument(osw, 'set_electric_equipment_bpr', 'wknd_bpr', wknd_plug_bpr) 
			
			#set swh template 
			OpenStudio::Extension.set_measure_argument(osw, 'set_service_water_heating_template', '__SKIP__', false)
			OpenStudio::Extension.set_measure_argument(osw, 'set_service_water_heating_template', 'as_constructed_template', comstock_const_vintage)
			OpenStudio::Extension.set_measure_argument(osw, 'set_service_water_heating_template', 'template', swh_vintage)
			OpenStudio::Extension.set_measure_argument(osw, 'set_service_water_heating_template', 'climate_zone', 'ASHRAE 169-2013-6A')
			
		    if building_type_1=='Food service'
           # # Electrify gas equipment 
				  OpenStudio::Extension.set_measure_argument(osw, 'electrify_gas_equipment', '__SKIP__', false)
		    end 
			
			#set hvac template 
		    OpenStudio::Extension.set_measure_argument(osw, 'set_hvac_template', '__SKIP__', false)
			OpenStudio::Extension.set_measure_argument(osw, 'set_hvac_template', 'as_constructed_template', comstock_const_vintage)
			OpenStudio::Extension.set_measure_argument(osw, 'set_hvac_template', 'template', hvac_vintage)
			OpenStudio::Extension.set_measure_argument(osw, 'set_hvac_template', 'climate_zone', 'ASHRAE 169-2013-6A')
			
			
			##AA moved this 12/7 
			OpenStudio::Extension.set_measure_argument(osw, 'add_hpwh', '__SKIP__', false)
		
			
			##AA moved this 12/7 
		   if commercial_building_types.include? building_type_1
           #Add Roof Top Unit Heat Pump
				OpenStudio::Extension.set_measure_argument(osw, 'add_heat_pump_rtu', '__SKIP__', false)
				OpenStudio::Extension.set_measure_argument(osw, 'add_heat_pump_rtu', 'backup_ht_fuel_scheme', 'electric_resistance_backup')
				#OpenStudio::Extension.set_measure_argument(osw, 'add_heat_pump_rtu', 'performance_oversizing_factor', 0.15)
		   end 
			
			
			
		    #set exterior lighting template 
		    OpenStudio::Extension.set_measure_argument(osw, 'set_exterior_lighting_template', '__SKIP__', false)
			OpenStudio::Extension.set_measure_argument(osw, 'set_exterior_lighting_template', 'as_constructed_template', comstock_const_vintage)
			OpenStudio::Extension.set_measure_argument(osw, 'set_exterior_lighting_template', 'template', ext_lighting_vintage)
			OpenStudio::Extension.set_measure_argument(osw, 'set_exterior_lighting_template', 'climate_zone', 'ASHRAE 169-2013-6A')
			
			#re run create typical building from model measure 
			# calling create typical building to assign HVAC systems
            #OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', '__SKIP__', false)
            #OpenStudio::Extension.set_measure_argument(osw, 'create_typical_building_from_model', 'system_type', system_type, 'create_typical_building_from_model')
		

          end
		  
		  #set output variables
		  # OpenStudio::Extension.set_measure_argument(osw, 'AddOutputVariable', 'variable_name', 'Heating Coil Heating Rate')
		  # OpenStudio::Extension.set_measure_argument(osw, 'AddOutputVariable', 'reporting_frequency', 'timestep')
		  # OpenStudio::Extension.set_measure_argument(osw, 'AddOutputVariable', 'variable_name', 'Heating Coil Electricity Rate')
          # OpenStudio::Extension.set_measure_argument(osw, 'AddOutputVariable', 'reporting_frequency', 'timestep')
		  
		   if commercial_building_types.include? building_type_1
           # needed for HP RTU measure 
				OpenStudio::Extension.set_measure_argument(osw, 'multispeed_minimum_flow', '__SKIP__', false)
		    end 
			
		 ##AA added 1/2
		  # OpenStudio::Extension.set_measure_argument(osw, 'AddOutputVariable', '__SKIP__', false)
          # OpenStudio::Extension.set_measure_argument(osw, 'AddOutputVariable', 'variable_name', 'Heating Coil Heating Rate')
		  # OpenStudio::Extension.set_measure_argument(osw, 'AddOutputVariable', 'reporting_frequency', 'timestep')
		  
		  # OpenStudio::Extension.set_measure_argument(osw, 'AddOutputVariable', '__SKIP__', false)
          # OpenStudio::Extension.set_measure_argument(osw, 'AddOutputVariable', 'variable_name', 'Heating Coil Electricity Rate')
		  # OpenStudio::Extension.set_measure_argument(osw, 'AddOutputVariable', 'reporting_frequency', 'timestep')
		  
		  
		  OpenStudio::Extension.set_measure_argument(osw, 'ithaca_add_reporting_variables', '__SKIP__', false)
		  
		  # OpenStudio::Extension.set_measure_argument(osw, 'export_variableto_csv_copy', '__SKIP__', false)
		  # OpenStudio::Extension.set_measure_argument(osw, 'export_variableto_csv_copy', 'variable_name', 'Fan Electricity Rate')
		  # OpenStudio::Extension.set_measure_argument(osw, 'export_variableto_csv_copy', 'reporting_frequency', 'Zone Timestep')
		  
		  # OpenStudio::Extension.set_measure_argument(osw, 'export_variableto_csv_copy', 'variable_name', 'Heating Coil Heating Rate')
		  # OpenStudio::Extension.set_measure_argument(osw, 'export_variableto_csv_copy', 'reporting_frequency', 'Zone Timestep')
		  
		  # OpenStudio::Extension.set_measure_argument(osw, 'export_variableto_csv_copy', 'variable_name', 'Heating Coil Electricity Rate')
		  # OpenStudio::Extension.set_measure_argument(osw, 'export_variableto_csv_copy', 'reporting_frequency', 'Zone Timestep')
		  
		  OpenStudio::Extension.set_measure_argument(osw, 'creat_csv_output', '__SKIP__', false)
		  OpenStudio::Extension.set_measure_argument(osw, 'creat_csv_output', 'reporting_frequency', 'Zone Timestep')
		  
          # call the default feature reporting measure
          OpenStudio::Extension.set_measure_argument(osw, 'default_feature_reports', 'feature_id', feature_id)
          OpenStudio::Extension.set_measure_argument(osw, 'default_feature_reports', 'feature_name', feature_name)
          OpenStudio::Extension.set_measure_argument(osw, 'default_feature_reports', 'feature_type', feature_type)
          OpenStudio::Extension.set_measure_argument(osw, 'default_feature_reports', 'feature_location', feature_location)
        end

        return osw
      end
    end # CreateBarMapper
  end # Scenario
end # URBANopt
