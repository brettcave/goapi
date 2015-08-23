
# We have selenium test suite that ran 11 hours 45 minutes in sequence on a 2 CPUs 3.5 GB memory VM.
# We configure 35 jobs on Go to run these tests. Tests are partitioned by [TLB] with a time based splitter.
# [TLB] should partition tests equally on build.
# But these jobs randomly ran from 18 minutes to 48 minutes. It seems really badly partitioned.
#
# This is one of scripts I wrote for myself to investigate the problem described above.
# We use ci_reporter to generate junit reports on build.
# This script fetches all junit reports on jobs of latest green stage.
# And try partition tests based on test run times in 2 ways:
#   1. random
#   2. test run time
#
# [TLB]: https://github.com/test-load-balancer/tlb

begin
  require 'descriptive-statistics'
rescue LoadError
  puts "Need descriptive-statistics to run this example"
  puts "You can install it by: gem install descriptive-statistics"
  exit(1)
end

server_url = <go server url>
username = <username>
password = <your password>
pipeline_name = <pipeline name>
stage_name = <stage name>
junit_report_file_name_regex = /TEST-[^.]+.xml/

lib_path = File.expand_path('../../lib', __FILE__)
$:.unshift(lib_path)

require 'goapi'
require 'rexml/document'

class JunitReport < Struct.new(:name, :tests)
  def self.parse(xml)
    root = REXML::Document.new(xml).root
    suite = root.attributes
    tests = []
    root.each_element('//testcase') do |e|
      tests << OpenStruct.new(name: "#{suite['name']}##{e.attributes['name']}", time: e.attributes['time'].to_f)
    end
    new(suite['name'], tests)
  end
end

go = GoAPI.new(server_url, basic_auth: [username, password])

stage = go.stages(pipeline_name, stage_name).find do |s|
  s.result == 'Passed'
end

require 'pstore'
store = PStore.new('pstore')
reports = store.transaction do
  store['reports'] ||= stage.jobs.map do |job|
    files = go.artifacts(stage, job.name).map{|a| a.type == 'folder' ? a.files : a}.flatten.select{|f| f.name =~ junit_report_file_name_regex}
    puts "Job #{job.name}, #{files.size} reports"
    files.map { |f| JunitReport.parse(go.artifact(f)) }
  end.compact.flatten
end

print_stats = lambda do |partitions|
  stats = DescriptiveStatistics::Stats.new(partitions.map {|p|p.map(&:time).reduce(:+).to_i})
  puts "partitions: #{partitions.size}"
  puts "mean: #{stats.mean}"
  puts "median: #{stats.median}"
  puts "max: #{stats.max}"
  puts "min: #{stats.min}"
  puts "standard deviation: #{stats.standard_deviation}"
end

tests = reports.map(&:tests).flatten
puts tests.size
puts tests.map(&:time).reduce(:+)/3600
puts "Random partition result:"
print_stats[tests.shuffle.each_slice(tests.size/35 + 1)]
puts ''
puts "Partitioned by test runtime"
bins = Array.new(35) { [] }
tests.sort_by(&:time).reverse.each do |test|
  bin = bins.min_by{|bin| bin.empty? ? 0 : bin.map(&:time).reduce(:+)}
  bin << test
end
print_stats[bins]

