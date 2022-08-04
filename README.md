# homebus-flume

This is a simple Homebus publisher which reads water consumption data from the Flume API and publishes it to a Homebus network.

This is still under development and is really not ready for use.

## Usage


```
bundle exec homebus-flume 
```

Will send a provisioning request to the Homebus server.


## Data Published

This program publishes the `org.homebus.experimental.water-flow`.

## Configuration

Configure using `.env`

- FLUME_DEVICE_ID=your-flume-device-id
- FLUME_USER_ID=your-flume-user-id
- FLUME_CLIENT_ID=your-flume-client-id
- FLUME_CLIENT_SECRET=your-flume-client-secret
- FLUME_USERNAME=your-email-address
- FLUME_PASSWORD=your-flume-password

We should retrieve the device ID and user ID from the Flume API.
