#
# Copyright (C) 2011 Onyx Point, Inc. <http://onyxpoint.com/>
#
# This file is part of the Onyx Point concat puppet module.
#
# The Onyx Point concat puppet module is free software: you can redistribute it
# and/or modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.
#
Puppet::Type.type(:concat_build ).provide :concat_build do
  require 'fileutils'

  desc "concat_build provider"

  def build_file(build = false)

    if File.directory?("/var/lib/puppet/concat/fragments/#{@resource[:name]}") and not build then
      # Just diff'ing - build the file but don't move it yet
      begin
        FileUtils.mkdir_p("/var/lib/puppet/concat/output")

        f = File.open("/var/lib/puppet/concat/output/#{@resource[:name]}.out", "w+")
        input_lines = Array.new
        Dir.chdir("/var/lib/puppet/concat/fragments/#{@resource[:name]}") do
          Array(@resource[:order]).flatten.each do |pattern|
             Dir.glob(pattern).sort_by{ |k| human_sort(k) }.each do |file|

              prev_line = nil
              File.open(file).each do |line|

                if @resource.squeeze_blank? and line =~ /^\s*$/ then
                  if prev_line == :whitespace then
                    next
                  else
                     prev_line = :whitespace
                  end
                end

                out = clean_line(line)
                if not out.nil? then
		  # This is a bit hackish, but it would be nice to keep as much
		  # of the file out of memory as possible in the general case.
                  if @resource.sort? or not @resource[:unique].eql?(:false) then
                    input_lines.push(line)
                  else
		    f.puts(line)
                  end
                end

              end

              if not @resource.sort? and @resource[:unique].eql?(:false) then
                # Separate the files by the specified delimiter.
                f.seek(-1, IO::SEEK_END)
                if f.getc.chr.eql?("\n") then
                  f.seek(-1, IO::SEEK_END)
                  f.print(String(@resource[:file_delimiter]))
                end
              end
            end
          end
        end

        if not input_lines.empty? then
          if @resource.sort? then
            input_lines = input_lines.sort_by{ |k| human_sort(k) }
          end
          if not @resource[:unique].eql?(:false) then
            if @resource[:unique].eql?(:uniq) then
              require 'enumerator'
              input_lines = input_lines.enum_with_index.map { |x,i|
                if x.eql?(input_lines[i+1]) then
                  nil
                else
                  x
                end
              }.compact
            else
              input_lines = input_lines.uniq
            end
          end

          f.puts(input_lines.join(@resource[:file_delimiter]))
        else
          # Ensure that the end of the file is a '\n'
          f.seek(-(String(@resource[:file_delimiter]).length), IO::SEEK_END)
          curpos = f.pos
          if not f.getc.chr.eql?("\n") then
            f.seek(curpos)
            f.print("\n")
          end
          f.truncate(f.pos)
        end

        f.close

      rescue Exception => e
        fail Puppet::Error, e
      end
    elsif File.directory?("/var/lib/puppet/concat/fragments/#{@resource[:name]}") and build then
      # This time for real - move the built file into the fragments dir
      if @resource[:target] and check_onlyif then
        debug "Copying /var/lib/puppet/concat/output/#{@resource[:name]}.out to #{@resource[:target]}"
        backup = `puppet filebucket backup --local --bucketdir=/var/lib/puppet/clientbucket #{@resource[:target]}`
        info "Filebucketing #{backup}".strip
        FileUtils.cp("/var/lib/puppet/concat/output/#{@resource[:name]}.out", @resource[:target])
      elsif @resource[:target] then
        debug "Not copying to #{@resource[:target]}, 'onlyif' check failed"
      elsif @resource[:onlyif] then
        debug "Specified 'onlyif' without 'target', ignoring."
      end
    elsif not @resource.quiet? then
      fail Puppet::Error, "The fragments directory at '/var/lib/puppet/concat/fragments/#{@resource[:name]}' does not exist!"
    end
  end

  private 

  # Return true if the command returns 0.
  def check_command(value)
    output, status = Puppet::Util::SUIDManager.run_and_capture([value])
    # The shell returns 127 if the command is missing.
    if status.exitstatus == 127
      raise ArgumentError, output
    end
 
    status.exitstatus == 0
  end

  def check_onlyif
    success = true

    if @resource[:onlyif] then
      cmds = [@resource[:onlyif]].flatten
      cmds.each do |cmd|
        return false unless check_command(cmd)
      end
    end

    success
  end

  def clean_line(line)
    newline = nil
    if Array(@resource[:clean_whitespace]).flatten.include?('leading') then
      line.sub!(/\s*$/, '')
    end
    if Array(@resource[:clean_whitespace]).flatten.include?('trailing') then
      line.sub!(/^\s*/, '')
    end
    if not (Array(@resource[:clean_whitespace]).flatten.include?('lines') and line =~ /^\s*$/) then
      newline = line
    end
    if @resource[:clean_comments] and line =~ /^#{@resource[:clean_comments]}/ then
      newline = nil
    end
    newline
  end

  def human_sort(obj)
    # This regex taken from http://www.bofh.org.uk/2007/12/16/comprehensible-sorting-in-ruby
    obj.to_s.split(/((?:(?:^|\s)[-+])?(?:\.\d+|\d+(?:\.\d+?(?:[eE]\d+)?(?:$|(?![eE\.])))?))/ms).map { |v| Float(v) rescue v.downcase}
  end

end
