require "sinatra"
require "omniauth-github"
require "octokit"
require "securerandom"
require "awesome_print" if ENV["RACK_ENV"] == "development"

GITHUB_KEY = ENV["GITHUB_KEY"]
GITHUB_SECRET = ENV["GITHUB_SECRET"]
SESSION_SECRET = ENV["SESSION_SECRET"] || SecureRandom.hex
STRAP_ISSUES_URL = ENV["STRAP_ISSUES_URL"] || \
                   "https://github.com/daptiv/strap/issues/new"
STRAP_BEFORE_INSTALL = ENV["STRAP_BEFORE_INSTALL"]
STRAP_CONTACT_PHONE = ENV["STRAP_CONTACT_PHONE"]

set :sessions, secret: SESSION_SECRET

use OmniAuth::Builder do
  options = { scope: "user:email,repo,write:public_key" }
  options[:provider_ignores_state] = true if ENV["RACK_ENV"] == "development"
  provider :github, GITHUB_KEY, GITHUB_SECRET, options
end

get "/auth/github/callback" do
  session[:auth] = request.env["omniauth.auth"]
  return_to = session.delete :return_to
  return_to = "/" if !return_to || return_to.empty?
  redirect to return_to
end

get "/" do
  if request.scheme == "http" && ENV["RACK_ENV"] != "development"
    redirect to "https://#{request.host}#{request.fullpath}"
  end

  before_install_list_item = nil
  if STRAP_BEFORE_INSTALL
    before_install_list_item = "<li>#{STRAP_BEFORE_INSTALL}</li>"
  end

  @title = "Strap"
  @head = <<-EOS
<link rel="stylesheet" href="app.css">
EOS
  @text = <<-EOS
Strap is a script to bootstrap a minimal macOS development system. This does not assume you're doing Ruby/Rails/web development but installs the minimal set of software every macOS developer will want.

To Strap your system:
<ol>
  #{before_install_list_item}
  <li><a href="/strap.sh">Download the <code>strap.sh</code></a> that's been customised for your GitHub user (or <a href="/strap.sh?text=1">view it</a> first). This will prompt for access to your email, public and private repositories; you'll need to provide access to any organizations whose repositories you need to be able to <code>git clone</code>. This is used to add a GitHub access token to the <code>strap.sh</code> script and is not otherwise used by this web application or stored anywhere.</li>
  <li>Run Strap in Terminal.app with <code>bash ~/Downloads/strap.sh</code>.</li>
  <li>If something failed, run Strap with more debugging output in Terminal.app with <code>bash ~/Downloads/strap.sh --debug</code> and file an issue at <a href="#{STRAP_ISSUES_URL}">#{STRAP_ISSUES_URL}</a></li>
  <li>Delete the customised <code>strap.sh</code></a> (it has a GitHub token in it) in Terminal.app with <code>rm -f ~/Downloads/strap.sh</code></a></li>
  <li>Install additional software with <code>brew install</code> and <code>brew cask install</code>.</li>
</ol>

<h3>Alternatively:  Run Strap with a Locally-Downloaded Vagrant Box</h3>
<p>If you want to use a previously downloaded Vagrant box, download <code>strap.sh</code> above and then run it with the following environment variables set.</p>
<table>
  <tbody>
    <tr><td><code>VAGRANT_LOCAL_BOX_PATH</code></td><td>Full path to the locally-downloaded box file.</td></tr>
    <tr><td><code>VAGRANT_LOCAL_BOX_VERSION</code></td><td>Version of the box file.</td></tr>
  </tbody>
</table>
<h4>Example</h4>
<p><code>VAGRANT_LOCAL_BOX_PATH=/Volumes/SanDisk/dev_ppm.box VAGRANT_LOCAL_BOX_VERSION=1.0.0 bash ~/Downloads/strap.sh</code></p>

<a href="https://github.com/daptiv/strap"><img style="position: absolute; top: 0; right: 0; border: 0; width: 149px; height: 149px;" src="//aral.github.com/fork-me-on-github-retina-ribbons/right-graphite@2x.png" alt="Fork me on GitHub"></a>
EOS
  erb :root
end

get "/strap.sh" do
  auth = session[:auth]

  if !auth && GITHUB_KEY && GITHUB_SECRET
    query = request.query_string
    query = "?#{query}" if query && !query.empty?
    session[:return_to] = "#{request.path}#{query}"
    redirect to "/auth/github"
  end

  content = IO.read(File.expand_path("#{File.dirname(__FILE__)}/../bin/strap.sh"))
  content.gsub!(/^STRAP_ISSUES_URL=.*$/, "STRAP_ISSUES_URL='#{STRAP_ISSUES_URL}'")

  content_type = params["text"] ? "text/plain" : "application/octet-stream"

  if auth
    content.gsub!(/^# STRAP_GIT_NAME=$/, "STRAP_GIT_NAME='#{auth["info"]["name"]}'")
    content.gsub!(/^# STRAP_GIT_EMAIL=$/, "STRAP_GIT_EMAIL='#{auth["info"]["email"]}'")
    content.gsub!(/^# STRAP_GITHUB_USER=$/, "STRAP_GITHUB_USER='#{auth["info"]["nickname"]}'")
    content.gsub!(/^# STRAP_GITHUB_TOKEN=$/, "STRAP_GITHUB_TOKEN='#{auth["credentials"]["token"]}'")
    content.gsub!(/^# STRAP_CONTACT_PHONE=$/, "STRAP_CONTACT_PHONE='#{STRAP_CONTACT_PHONE}'")
  end

  erb content, content_type: content_type
end
