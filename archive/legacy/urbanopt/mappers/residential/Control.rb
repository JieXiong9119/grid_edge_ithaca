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

require 'json'
require 'csv'

module URBANopt
  module Scenario
    class ControlMapper < BaselineMapper
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

          # WINDOWS, INFILTRATION, and INFILTRATION reassignment
          climate_zone = '6A'
          location_region = 'CR02'
          wall_type = 'Brick'
          year_built = feature.year_built
          building_type = feature.building_type
          floor_area = feature.floor_area
          attic_type = feature.attic_type

          if year_built <1940
            year_name = '<1940'
          elsif year_built >=1940 and year_built <1960
            year_name = '1940-59'
          elsif year_built >=1960 and year_built <1980 
            year_name = '1960-79'
          elsif year_built >=1980 and year_built <1999
            year_name = '1980-99'
          elsif year_built >=2000 and year_built <2010
            year_name = '2000-09'
          elsif year_built >=2010
            year_name = '2010s'
          else
            year_name = 'unknown'
          end

          if year_built <1940
            vintage = '<1940'
          elsif year_built >=1940 and year_built <1950
            vintage = '1940s'
          elsif year_built >=1950 and year_built <1960
            vintage = '1950s'
          elsif year_built >=1960 and year_built <1970
            vintage = '1960s'
          elsif year_built >=1970 and year_built <1980
            vintage = '1970s'
          elsif year_built >=1980 and year_built <1990
            vintage = '1980s'
          elsif year_built >=1990 and year_built <2000
            vintage = '1990s'
          elsif year_built >=2000 and year_built <2010
            vintage = '2000s'
          elsif year_built >=2010
            vintage = '2010s'
          else
            vintage = 'unknown'
          end

          if floor_area <500
            floor_area_name = '0-499'
          elsif floor_area >=500 and floor_area <749
            floor_area_name = '500-749'
          elsif floor_area >=750 and floor_area <999
            floor_area_name = '750-999'
          elsif floor_area >=1000 and floor_area <1499
            floor_area_name = '1000-1499'
          elsif floor_area >=1500 and floor_area <1999
            floor_area_name = '1500-1999'
          elsif floor_area >=2000 and floor_area <2499
            floor_area_name = '2000-2499'
          elsif floor_area >=2500 and floor_area <2999
            floor_area_name = '2500-2999'
          elsif floor_area >=3000 and floor_area <3999
            floor_area_name = '3000-3999'
          elsif floor_area >=4000
            floor_area_name = '4000+'
          else
            floor_area_name = 'unknown'
          end

          if attic_type == 'attic - vented'
            attic_type_name = 'Vented Attic'
          elsif attic_type == 'attic - unvented'
            attic_type_name = 'Unvented Attic'
          else
            attic_type_name = 'unknown'
          end

          if building_type == 'Single-Family Detached'
            building_name = 'Single-Family Detached'
          elsif building_type == 'Multifamily'
            building_name = 'Multi-Family with 2 - 4 Units'
          else
            building_name = 'unknown'
          end

          # WINDOWS
          # Read from windows TSV to find window option names and probability distributions of window types
          probs = []
          windows_filepath = File.join(File.dirname(__FILE__), 'residential/windows.tsv')
          toprow = CSV.open(windows_filepath, { col_sep: "\t" }) { |csv| csv.first }
          toprow = toprow[3..12]
          for col in toprow do
            col.slice! 'Option='
          end

          CSV.foreach(windows_filepath, { col_sep: "\t" }) do |row|
            if (row[0] == climate_zone) and (row[1] == building_name) and (row[2] == year_name)
              probs = row[3..12]
            end
          end

          # Read from Options Lookup TSV to find U-factors needed
          windowus2 = []
          options_filepath = File.join(File.dirname(__FILE__), 'residential/options_lookup.tsv')
          toprow.each_with_index do |name, index|
            CSV.foreach(options_filepath, { col_sep: "\t" }) do |row|
              if row[1] == name
                string = row[3] 
                string.slice! 'window_ufactor='
                windowus2[index] = string
              end
            end
          end

          windowus = windowus2.map {|a| (a.to_f)}
          probs = probs.map {|a| 100*(a.to_f)} # Multiply probabilities by 100 (to change from 0-1 to 0-100)

          random = rand(0..100) # Choose a random number between 0 and 100
          probstart = 0 # Initialize probability as 0
          probs.each_with_index do |value, index|
            totalprob = probstart + value
            chosen = index
            if random <= totalprob
              args[:window_ufactor] = windowus[index]
              break
            elsif random > totalprob
              probstart = totalprob
            end
          end
      
          # INFILTRATION
          # Read from infiltration TSV to find infiltration option names and probability distributions of infiltration types
          probs = []
          infiltration_filepath = File.join(File.dirname(__FILE__), 'residential/Infiltration.tsv')
          toprow = CSV.open(infiltration_filepath, { col_sep: "\t" }) { |csv| csv.first }
          toprow = toprow[3..17]
          for col in toprow do
            col.slice! 'Option='
            col.slice! ' ACH50'
          end

          CSV.foreach(infiltration_filepath, { col_sep: "\t" }) do |row|
            if (row[0] == climate_zone) and (row[1] == floor_area_name) and (row[2] == vintage)
              probs = row[3..17]
            end
          end

          infilts = toprow
          infilts = infilts.map {|a| (a.to_f)}
          probs = probs.map {|a| 100*(a.to_f)} # Multiply probabilities by 100 (to change from 0-1 to 0-100)

          random = rand(0..100) # Choose a random number between 0 and 100
          probstart = 0 # Initialize probability as 0
          probs.each_with_index do |value, index|
            totalprob = probstart + value
            chosen = index
            if random <= totalprob
              args[:air_leakage_value] = infilts[index]
              break
            elsif random > totalprob
              probstart = totalprob
            end
          end

          # CEILING INSULATION
          # Read from insulation ceiling TSV to find insulation  option names and probability distributions of insulation types
          probs = []
          insulation_filepath = File.join(File.dirname(__FILE__), 'residential/Insulation Ceiling.tsv')
          toprow = CSV.open(insulation_filepath, { col_sep: "\t" }) { |csv| csv.first }
          toprow = toprow[4..10]
          for col in toprow do
            if col.include? 'Option=R-'
              col.slice! 'Option=R-'
            else
              col = 0
            end
          end

          CSV.foreach(insulation_filepath, { col_sep: "\t" }) do |row|
            if (row[0] == attic_type_name) and (row[1] == location_region) and (row[2] == vintage)
              probs = row[4..10]
            end
          end

          insulas = toprow
          insulas = insulas.map {|a| (a.to_f)}
          probs = probs.map {|a| 100*(a.to_f)} # Multiply probabilities by 100 (to change from 0-1 to 0-100)

          random = rand(0..100) # Choose a random number between 0 and 100
          probstart = 0 # Initialize probability as 0
          probs.each_with_index do |value, index|
            totalprob = probstart + value
            chosen = index
            if random <= totalprob
              args[:ceiling_assembly_r] = insulas[index]
              break
            elsif random > totalprob
              probstart = totalprob
            end
          end
          
          # WALL INSULATION
          # Read from insulation wall TSV to find insulation  option names and probability distributions of insulation types
          probs = []
          insulationwall_filepath = File.join(File.dirname(__FILE__), 'residential/Insulation Wall.tsv')
          toprow = CSV.open(insulationwall_filepath, { col_sep: "\t" }) { |csv| csv.first }
          toprow = toprow[13..17]
          toprow.each_with_index do |col,index|
            if col.include? 'R-'
              toprow[index] = col.partition('R-').last.to_f
            else
              toprow[index] = 1
            end
          end

          CSV.foreach(insulationwall_filepath, { col_sep: "\t" }) do |row|
            if (row[0] == location_region) and (row[1] == vintage) and (row[2] == wall_type)
              probs = row[13..17]
            end
          end

          insulaswall = toprow
          insulaswall = insulaswall.map {|a| (a.to_f)}
          probs = probs.map {|a| 100*(a.to_f)} # Multiply probabilities by 100 (to change from 0-1 to 0-100)

          puts"##### toprow #{toprow}"
          puts"##### probs #{probs}"


          random = rand(0..100) # Choose a random number between 0 and 100
          probstart = 0 # Initialize probability as 0
          probs.each_with_index do |value, index|
            totalprob = probstart + value
            chosen = index
            if random <= totalprob
              args[:wall_assembly_r] = insulaswall[index]
              break
            elsif random > totalprob
              probstart = totalprob
            end
          end

          args.each do |arg_name, arg_val|
            OpenStudio::Extension.set_measure_argument(osw, 'BuildResidentialModel', arg_name, arg_val)
          end

        # Commercial Buildings
        elsif commercial_building_types.include? building_type
          # Apply any changes that need to be made to control case commercial buildings
        
        end

        return osw
      end
    end
  end
end
