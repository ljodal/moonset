require 'rinda/tuplespace'
require 'pygmentize'

ts = Rinda::TupleSpace.new

DRb.start_service(nil, ts)

url = DRb.uri

ts.write(["job", "some path", "another path"])

2.times do
  pid = fork
  unless pid
    DRb.start_service
    ts=DRbObject.new(nil, url)
    puts ts.take(["job", String, String])
    for line in File.readlines("generator.rb")
      puts line
      Pygmentize.process(line, "ruby");
    end
    puts "Done"
    exit
  end
end

Process.wait

puts "All processes have exited"

# Join with drb thread to avoid exit..
#DRb.thread.join

puts("Server Dead")
