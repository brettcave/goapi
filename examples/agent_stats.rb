
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
  puts "fetch jobs' properties for #{go.stage_id(stage)}"
  stage.jobs.map do |job|
    go.job_properties(stage, job.name)
  end
end.flatten.map do |job|
  [job.cruise_agent, job.cruise_job_duration.to_i]
end.group_by do |tmp|
  tmp[0]
end.map do |agent, jobs|
  times = jobs.map{|t| t[1]}
  [agent, times.reduce(:+)/times.size, times.sort[times.size/2], times.size]
end.sort_by{|r| r[1]}.reverse.each do |agent, avg, m, size|
  puts "#{agent} ran #{size} jobs, avg time: #{avg.to_i} secs; median time: #{m.to_i} secs"
end
