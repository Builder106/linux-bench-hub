require 'net/ssh'
require 'json'
require 'open3'
require 'socket'
require 'timeout'
require 'fileutils'

def start_vm(vm_path)
  stdout, stderr, status = Open3.capture3("vmrun", "start", vm_path)
  if status.success?
    puts "Successfully started VM: #{vm_path}"
  else
    puts "Failed to start VM: #{vm_path}, Error: #{stderr}"
    exit(1) # Exit if VM can't be started
  end
end

def get_vm_ip(vm_path)
  retries = 5
  begin
    stdout, stderr, status = Open3.capture3("vmrun", "getGuestIPAddress", vm_path)
    if status.success?
      ip = stdout.strip
      if ip.empty?
        raise "Empty IP address"
      end
      puts "VM IP address: #{ip}"
      return ip
    else
      raise stderr
    end
  rescue => e
    if (retries -= 1) > 0
      puts "Failed to get VM IP address: #{e.message}, retrying in 10 seconds... (#{retries} retries left)"
      sleep 10
      retry
    else
      puts "Failed to get VM IP address after multiple attempts: #{e.message}"
      exit(1)
    end
  end
end

def shutdown_vm(vm_path)
  stdout, stderr, status = Open3.capture3("vmrun", "stop", vm_path, "soft")
  if status.success?
    puts "Successfully shut down VM: #{vm_path}"
  else
    puts "Failed to shut down VM: #{vm_path}, Error: #{stderr}"
  end
end

def port_open?(ip, port, seconds=1)
  Timeout::timeout(seconds) do
    begin
      TCPSocket.new(ip, port).close
      true
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError
      false
    end
  end
rescue Timeout::Error
  false
end

def ensure_packages_installed(ssh)
  packages = ['build-essential', 'php-cli', 'php-xml']
  packages.each do |pkg|
    result = ssh.exec!("dpkg -l | grep #{pkg}")
    if result.empty?
      puts "Installing package: #{pkg}"
      ssh.exec!("sudo apt-get update && sudo apt-get install -y #{pkg}")
    end
  end
end

def test_installed?(ssh, test_name)
  result = ssh.exec!("phoronix-test-suite list-installed-tests")
  result.include?(test_name)
end

def install_test(ssh, test_name)
  puts "Installing test: #{test_name}"
  ssh.exec!("phoronix-test-suite install #{test_name}")
end

def run_benchmark(vm_ip, username, password, test_name)
  puts "Running benchmark #{test_name} on VM at #{vm_ip}..."
  retries = 5
  begin
    Net::SSH.start(vm_ip, username, password: password) do |ssh|
      ensure_packages_installed(ssh)

      unless test_installed?(ssh, test_name)
        install_test(ssh, test_name)
      end

      result = nil
      begin
        Timeout::timeout(1800) do # Set a timeout of 30 minutes for the benchmark
          result = ssh.exec!("echo 'y' | phoronix-test-suite batch-benchmark #{test_name}")
        end
      rescue Timeout::Error
        puts "Benchmark #{test_name} on VM at #{vm_ip} timed out."
        return
      end

      # Create the directory if it doesn't exist
      dir = "benchmark_results"
      FileUtils.mkdir_p(dir)
      # Save the benchmark result to a JSON file
      File.open("#{dir}/benchmark_results_#{vm_ip}_#{test_name.gsub('/', '_')}.json", "w") do |file|
        file.write(result)
      end
    end
    puts "Completed benchmark #{test_name} on VM at #{vm_ip}."
  rescue Net::SSH::ConnectionTimeout, Errno::ETIMEDOUT => e
    if (retries -= 1) > 0
      puts "SSH connection failed, retrying in 10 seconds... (#{retries} retries left)"
      sleep 10
      retry
    else
      puts "Failed to connect to VM at #{vm_ip} after multiple attempts: #{e.message}"
      exit(1)
    end
  end
end

def open_terminal_and_run_commands(vm_ip, username, password, commands)
  Net::SSH.start(vm_ip, username, password: password) do |ssh|
    ssh.open_channel do |channel|
      channel.request_pty do |ch, success|
        if success
          puts "PTY successfully obtained"
        else
          puts "Failed to obtain PTY"
          exit(1)
        end
      end

      channel.exec("bash") do |ch, success|
        if success
          puts "Opened bash shell"
          commands.each do |command|
            ch.send_data("#{command}\n")
          end
          ch.send_data("exit\n")
        else
          puts "Failed to open bash shell"
          exit(1)
        end
      end

      channel.on_data do |ch, data|
        puts data
      end

      channel.on_extended_data do |ch, type, data|
        puts "STDERR: #{data}"
      end

      channel.on_close do |ch|
        puts "Channel closed"
      end
    end

    ssh.loop
  end
end

# Example VM paths (replace with actual .vmx paths)
vm_paths = {
  "Ubuntu" => "/Users/yinka/Virtual Machines.localized/Ubuntu 24.04.1.vmwarevm/Ubuntu 64-bit 24.04.1.vmx",
  "Debian" => "/Users/yinka/Virtual Machines.localized/Debian 12.7.vmwarevm/Debian 12.x 64-bit.vmx",
  "Fedora" => "/Users/yinka/Virtual Machines.localized/Fedora 40.vmwarevm/Fedora 64-bit.vmx"
}

# Example VM details (replace with actual usernames and passwords)
common_tests = ['pts/c-ray', 'pts/tinymembench', 'pts/aircrack-ng']

vm_details = {
  "Ubuntu" => { username: 'yinka', password: '1234', tests: common_tests },
  "Debian" => { username: 'yinka', password: '1234', tests: common_tests },
  "Fedora" => { username: 'yinka', password: '1234', tests: common_tests }
}

# Process each VM one at a time
vm_paths.each do |name, vm_path|
  puts "Processing VM: #{name}"
  
  # Start the VM
  start_vm(vm_path)
  
  # Wait for the VM to boot up
  sleep 60
  
  # Get the IP address of the VM
  vm_ip = get_vm_ip(vm_path)
  
  # Get the details for the current VM
  vm = vm_details[name]
  
  # Check if SSH port is open
  retries = 5
  begin
    unless port_open?(vm_ip, 22)
      puts "Checking SSH service status on VM at #{vm_ip}..."
      stdout, stderr, status = Open3.capture3("ssh", "#{vm[:username]}@#{vm_ip}", "sudo systemctl status ssh")
      puts stdout
      raise "SSH port is not open on VM at #{vm_ip}"
    end
  rescue => e
    if (retries -= 1) > 0
      puts "#{e.message}, retrying in 10 seconds... (#{retries} retries left)"
      sleep 10
      retry
    else
      puts "Failed to connect to VM at #{vm_ip} after multiple attempts: #{e.message}"
      exit(1)
    end
  end
  
  # Open terminal and run commands
  commands = [
    "echo 'y' | phoronix-test-suite batch-benchmark #{vm[:tests].join(' ')}"
  ]
  open_terminal_and_run_commands(vm_ip, vm[:username], vm[:password], commands)
  
  # Shut down the VM
  shutdown_vm(vm_path)
  puts "Finished processing VM: #{name}\n\n"
end