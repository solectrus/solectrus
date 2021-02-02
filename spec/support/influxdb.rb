def add_influx_point(name, fields)
  influx_client = Flux::Base.new.client
  write_api = influx_client.create_write_api

  write_api.write(
    data:   {
      name: name,
      fields: fields
    },
    bucket: ENV['INFLUX_BUCKET'],
    org:    ENV['INFLUX_ORG']
  )
end
