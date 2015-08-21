
server_url = <go server url>
username = <username>
password = <your password>
pipeline_name = <pipeline name>
stage_name = <stage name>

lib_path = File.expand_path('../../lib', __FILE__)
$:.unshift(lib_path)

require 'goapi'

go = GoAPI.new(server_url, basic_auth: [username, password])
go.stages(pipeline_name, stage_name).select do |s|
  s.result == 'Passed'
end.map do |stage|
  stage.jobs.map do |job|
    properties = go.job_properties(stage, job.name)
    OpenStruct.new(properties.to_h.merge(name: job.name))
  end
end.flatten.group_by(&:name).map do |name, jobs|
  times = jobs.map(&:cruise_job_duration).map(&:to_i)
  [name, times.reduce(:+)/times.size, times.sort[times.size/2], times.size]
end.sort_by{|r| r[1]}.reverse.each do |name, avg, m, size|
  puts "#{name} avg time: #{avg.to_i} secs; median time: #{m.to_i} secs"
end
