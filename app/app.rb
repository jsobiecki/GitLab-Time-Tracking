require 'awesome_print'
require 'gitlab'
require 'omniauth'
require 'omniauth-gitlab'
require 'sinatra'
require_relative 'gitlab_downloader'
require_relative 'csv_exporter'
require_relative 'mongo_connection'

set :logging, :true
set :show_exceptions, true 

use Rack::Session::Pool
set :session_secret, 'Password!' # TODO Change this to a ENV

use OmniAuth::Builder do
	provider :gitlab, ENV["GITLAB_CLIENT_ID"], ENV["GITLAB_CLIENT_SECRET"]
end



# Testing code - Outputs the Client ID and Secrect to the Console to ensure that the ENV was taken
# ap ENV["GITLAB_CLIENT_ID"]
# ap ENV["GITLAB_CLIENT_SECRET"]
# End of Testing Code


helpers do
	def current_user
		session["private_token"]
	end

	def mongoConnection
		if @mongoConnection == nil
			@mongoConnection = Mongo_Connection.new(ENV["MONGODB_HOST"], ENV["MONGODB_PORT"].to_i, ENV["MONGODB_DB"], ENV["MONGODB_COLL"])
		else
			@mongoConnection
		end
	end
end

get '/' do
	if current_user != nil
		'<p> Dashboard will go here </p>
		<br>
		<a href="/download">Download Data</a>'
	else
		'<h1> Welcome to GitLab Time Tracking</h1>
		<br>
		<a href="/sign_in">sign in with GitLab</a>'
	end
end

get '/download' do

	'<a href="/gl-download/153287">Download data from GitLab into MongoDB (project id: 153287)</a>
	<p>url pattern is: localhost:4567/gl-download/PROJECT_ID
	<br><br>
	<a href="/download-csv">Download data from MongoDB to .CSV</a>
	<br>
	<a href="/clear-mongo">Clear MongoDB Database</a>'

end

get '/clear-mongo' do

	mongoConnection.clear_mongo_collections
	redirect '/'

end



get '/download-csv' do
	dataExportConnection = CSVExporter.new(mongoConnection)
	dataExport = dataExportConnection.get_all_issues_time

	content_type 'application/csv'
	attachment "GitLab-Time-Tracking-Data.csv"

	csv = dataExportConnection.generateCSV(dataExport)
end


get '/gl-download/:projectid' do
	# TODO move MongoConnection to a Session connection so it does not need to reconnect every time
	# m = Mongo_Connection.new(ENV["MONGODB_HOST"], ENV["MONGODB_PORT"].to_i, ENV["MONGODB_DB"], ENV["MONGODB_COLL"])

	# m = Mongo_Connection.new("localhost", 27017, "GitLab-TimeTracking", "TimeTrackingCommits")
	# @mongoConnection.clear_mongo_collections

	g = GitLab_Downloader.new("https://gitlab.com/api/v3", current_user)

	projectID = params[:projectid]

	issuesWithComments = g.downloadIssuesAndComments(projectID)
	mongoConnection.putIntoMongoCollTimeTrackingCommits(issuesWithComments)

	redirect '/'

end

get '/auth/:name/callback' do
	auth = request.env["omniauth.auth"]
	# @private_token = auth["extra"]["raw_info"]["private_token"]
		session["private_token"] = auth["extra"]["raw_info"]["private_token"]
		
		# Testing Code
		# ap current_user


	# session[:user_id] = auth["uid"]
	redirect '/'
end

# any of the following routes should work to sign the user in: 
#   /sign_up, /signup, /sign_in, /signin, /log_in, /login
["/sign_in/?", "/signin/?", "/log_in/?", "/login/?", "/sign_up/?", "/signup/?"].each do |path|
	get path do
		redirect '/auth/gitlab'
	end
end

# either /log_out, /logout, /sign_out, or /signout will end the session and log the user out
["/sign_out/?", "/signout/?", "/log_out/?", "/logout/?"].each do |path|
	get path do
		# session[:user_id] = nil
		# @private_token = nil
		redirect '/'
	end
end