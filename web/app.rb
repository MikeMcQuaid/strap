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
Strap is a script to bootstrap a minimal macOS development system for Daptiv developers and testers.

<h2>To Strap your system:</h2>
<p class="note">(If you have locally-downloaded your Vagrant box, see alternate instructions below.)</p>
<ol>
  #{before_install_list_item}
  <li><a href="/strap.sh">Download the <code>strap.sh</code></a> that's been customised for your GitHub user.
    <ul>
      <li>This will prompt for access to your email, public and private repositories; you'll need to provide access to the Daptiv organization so Strap can access its repositories.</li>
      <li>The permissions above are used to add a GitHub access token to the <code>strap.sh</code> script and is not otherwise used by this web application or stored anywhere.</li>
      <li>You can <a href="/strap.sh?text=1">view the file</a> first if you want.</li>
    </ul>
  </li>
  <li>Run Strap in Terminal.app with <code>bash ~/Downloads/strap.sh --parallels-key <your-key-here></code> where you replace <code><your-key-here></code> with your parallels license key.</li>
  <li>Once Strap completes, delete the customised <code>strap.sh</code></a> (it has a GitHub token in it) in Terminal.app with <code>rm -f ~/Downloads/strap.sh</code></a>.</li>
</ol>

<h3>Troubleshooting</h3>
If something failed, run Strap with more debugging output in Terminal.app with <code>bash ~/Downloads/strap.sh --debug</code> and file an issue at <a href="#{STRAP_ISSUES_URL}">#{STRAP_ISSUES_URL}</a>.

<h3>Customization</h3>
Install additional software using Homebrew via your <a href="https://sites.google.com/a/daptiv.com/portal/Daptiv-Engineering-Wiki/dev-machine-setup/personal-dotfiles-repository">personal dotfiles repository</a>.

<h3 class="separator">Alternatively:  Run Strap with a Locally-Downloaded Vagrant Box</h3>
<p>If you want to use a previously downloaded Vagrant box, download <code>strap.sh</code> above and then run it with the following environment variables set.</p>
<table>
  <tbody>
    <tr><td><code>VAGRANT_LOCAL_BOX_PATH</code></td><td>Full path to the locally-downloaded box file.</td></tr>
    <tr><td><code>VAGRANT_LOCAL_BOX_VERSION</code></td><td>Version of the box file.</td></tr>
  </tbody>
</table>
<h4>Example</h4>
<p><code>VAGRANT_LOCAL_BOX_PATH=/Volumes/SanDisk/dev_ppm.box VAGRANT_LOCAL_BOX_VERSION=1.0.0 bash ~/Downloads/strap.sh</code></p>
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
