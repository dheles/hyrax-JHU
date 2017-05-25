namespace :clean do

  task :type, [:type] =>  [:environment] do |t, args|
    puts "Removing all items of type [#{args[:type]}]"

    klass = Kernel.const_get(args[:type]).all.each do |item|
      item.destroy
    end
  end
end
