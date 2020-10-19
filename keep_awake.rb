require './dependencies'

heroku_service_url = ENV['HEROKU_SERVICE_URL']
# to keep heroku alive
begin
  response = RestClient.get("#{heroku_service_url}")
rescue RestClient::Exception => e
  error = e
end