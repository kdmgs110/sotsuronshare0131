Shindo.tests('Fog::Compute[:aws] | address requests', ['aws']) do
  compute = Fog::Compute[:aws]

  @addresses_format = {
    'addressesSet' => [{
      'allocationId'  => Fog::Nullable::String,
      'associationId' => Fog::Nullable::String,
      'domain'        => String,
      'instanceId'    => Fog::Nullable::String,
      'publicIp'      => String
    }],
    'requestId' => String
  }
  @server = compute.servers.create
  @server.wait_for { ready? }
  @ip_address = @server.public_ip_address

  tests('success') do

    @public_ip = nil
    @vpc_public_ip = nil
    @vpc_allocation_id = nil

    tests('#allocate_address').formats({'domain' => String, 'publicIp' => String, 'requestId' => String}) do
      data = compute.allocate_address.body
      @public_ip = data['publicIp']
      data
    end

    tests("#allocate_address('vpc')").formats({'domain' => String, 'publicIp' => String, 'allocationId' => String, 'requestId' => String}) do
      data = compute.allocate_address('vpc').body
      @vpc_public_ip = data['publicIp']
      @vpc_allocation_id = data['allocationId']
      data
    end

    tests('#describe_addresses').formats(@addresses_format) do
      compute.describe_addresses.body
    end

    tests("#describe_addresses('public-ip' => #{@public_ip}')").formats(@addresses_format) do
      compute.describe_addresses('public-ip' => @public_ip).body
    end

    tests("#associate_addresses('#{@server.identity}', '#{@public_ip}')").formats(AWS::Compute::Formats::BASIC) do
      compute.associate_address(@server.identity, @public_ip).body
    end

    tests("#associate_addresses({:instance_id=>'#{@server.identity}', :public_ip=>'#{@public_ip}'})").formats(AWS::Compute::Formats::BASIC) do
      compute.associate_address({:instance_id=>@server.identity,:public_ip=> @public_ip}).body
    end

    tests("#dissassociate_address('#{@public_ip}')").formats(AWS::Compute::Formats::BASIC) do
      compute.disassociate_address(@public_ip).body
    end

    tests("#associate_addresses('#{@server.id}', nil, nil, '#{@vpc_allocation_id}')").formats(AWS::Compute::Formats::BASIC) do
      compute.associate_address(@server.id, nil, nil, @vpc_allocation_id).body
    end

    tests("#associate_addresses({:instance_id=>'#{@server.id}', :allocation_id=>'#{@vpc_allocation_id}'})").formats(AWS::Compute::Formats::BASIC) do
      compute.associate_address({:instance_id=>@server.id, :allocation_id=>@vpc_allocation_id}).body
    end

    tests("#release_address('#{@public_ip}')").formats(AWS::Compute::Formats::BASIC) do
      compute.release_address(@public_ip).body
    end

    tests("#release_address('#{@vpc_allocation_id}')").formats(AWS::Compute::Formats::BASIC) do
      compute.release_address(@vpc_allocation_id).body
    end
  end

  tests('failure') do

    @address     = compute.addresses.create
    @vpc_address = compute.addresses.create(:domain => 'vpc')

    tests("#associate_addresses({:instance_id =>'i-00000000', :public_ip => '#{@address.identity}')}").raises(Fog::Compute::AWS::NotFound) do
      compute.associate_address({:instance_id => 'i-00000000', :public_ip => @address.identity})
    end

    tests("#associate_addresses({:instance_id =>'#{@server.identity}', :public_ip => '127.0.0.1'})").raises(Fog::Compute::AWS::Error) do
      compute.associate_address({:instance_id => @server.identity, :public_ip => '127.0.0.1'})
    end

    tests("#associate_addresses({:instance_id =>'i-00000000', :public_ip => '127.0.0.1'})").raises(Fog::Compute::AWS::NotFound) do
      compute.associate_address({:instance_id =>'i-00000000', :public_ip =>'127.0.0.1'})
    end

    tests("#disassociate_addresses('127.0.0.1') raises BadRequest error").raises(Fog::Compute::AWS::Error) do
      compute.disassociate_address('127.0.0.1')
    end

    tests("#release_address('127.0.0.1')").raises(Fog::Compute::AWS::Error) do
      compute.release_address('127.0.0.1')
    end

    tests("#release_address('#{@vpc_address.identity}')").raises(Fog::Compute::AWS::Error) do
      compute.release_address(@vpc_address.identity)
    end

    if Fog.mocking?
      old_limit = compute.data[:limits][:addresses]

      tests("#allocate_address", "limit exceeded").raises(Fog::Compute::AWS::Error) do
        compute.data[:limits][:addresses] = 0
        compute.allocate_address
      end

      compute.data[:limits][:addresses] = old_limit
    end

    @address.destroy
    @vpc_address.destroy

  end

  @server.destroy

end
