require "net/http"
require "uri"
require "json"
# require "mime/types"

module BxBlockDocumentstorage
  class ZohoWorkDriveService
    BASE_URL = 'https://www.zohoapis.com/workdrive/api/v1'
    TOKEN_URL = 'https://accounts.zoho.com/oauth/v2/token'
    ZOHO_OAUTH = "Zoho-oauthtoken"
    CONTENT_TYPE = "Content-Type"
    APP_JSON = "application/json"

    def initialize
      @access_token = fetch_access_token
    end

    # Get Team Info
    # 't25co95b1228ede134ce8980d5690b2e3c5f1'
    def get_team_info(team_id)
      uri = URI("#{BASE_URL}/teams/#{team_id}")
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{@access_token}"
      request[CONTENT_TYPE] = APP_JSON

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      parsed_response = parse_response(response)
      parsed_response
    rescue StandardError => e
      raise "Error fetching team info: #{e.message}"
    end

    # 'du116286a533b6bcd4ce9a364bca61662cdfd'
    def get_team_folder_files(teamfolder_id)
      uri = URI("#{BASE_URL}/teamfolders/#{teamfolder_id}/files")
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{@access_token}"
      request[CONTENT_TYPE] = APP_JSON
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      parsed_response = parse_response(response)
      parsed_response
    rescue StandardError => e
      raise "Error fetching team folder files: #{e.message}"
    end

    # Get List of Sub Folders
    # Fetch sub folders inside a team folder
    # 'du116286a533b6bcd4ce9a364bca61662cdfd'
    def get_team_folder_sub_folders(teamfolder_id)
      uri = URI("#{BASE_URL}/teamfolders/#{teamfolder_id}/folders")
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{@access_token}"
      request[CONTENT_TYPE] = APP_JSON

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      parsed_response = parse_response(response)
      parsed_response
    rescue StandardError => e
      raise "Error fetching subfolders: #{e.message}"
    end

    # create folder for team
    def create_folder(folder_name, parent_id, is_public_within_team, description)
      uri = URI("#{BASE_URL}/teamfolders")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@access_token}"
      request[CONTENT_TYPE] = APP_JSON

      folder_data = {
        data: {
          attributes: {
            name: folder_name,
            parent_id: parent_id,
            is_public_within_team: is_public_within_team.to_s,  # true or false
            description: description
          },
          type: "teamfolders"
        }
      }

      request.body = folder_data.to_json

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request(request)
      end
      puts "Response body: #{response.body}"
      parsed_response = parse_response(response)
      parsed_response
    rescue StandardError => e
      raise "Error creating folder: #{e.message}"
    end

    #organization folder
    # parent_folder_id = r582h4c55ef0250f74aeeb15d2a1a365cf2b0
    def create_folders_with_subfolders(company, parent_folder_id)
      company_name = "#{company.id}-#{company.company_name}"
      parent_folder = folder_in_folder(name, parent_folder_id)
      if parent_folder.present?
        subfolders = ["Environment", "Social", "Governance", "Other Certifications"]

        subfolders.each do |subfolder_name|
          folder_in_folder(subfolder_name, parent_folder["data"]["id"])
        end
      else
        raise "Failed to create parent folder"
      end
    end

    #normal folder creation
    def add_folder(name, parent_folder_id)
      folder_in_folder(name, parent_folder_id)
    end

    def upload_file(file_path, folder_id, override_name_exist = "false")
      uri = URI("https://www.zohoapis.com/workdrive/api/v1/upload")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Zoho-oauthtoken #{@access_token}"

      file = File.open(file_path)

      form_data = [
        ['content', file],
        ['parent_id', folder_id],
        ['override-name-exist', override_name_exist]
      ]

      request.set_form form_data, 'multipart/form-data'

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      file.close

      parse_response(response)
    rescue StandardError => e
      raise "Error uploading file: #{e.message}"
    end

    def add_team_member(email, category_id, role_id)
      uri = URI("#{BASE_URL}/users")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@access_token}"
      request[CONTENT_TYPE] = APP_JSON
      body = {
        data: [
          {
            attributes: {
              email_id: email,
              category_id: category_id,
              role_id: role_id
            },
            type: "users"
          }
        ]
      }.to_json

      request.body = body

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      parsed_response = parse_response(response)
      parsed_response
    rescue StandardError => e
      raise "Error adding team member: #{e.message}"
    end

  private

    def fetch_access_token
      uri = URI(TOKEN_URL)
      params = {
        refresh_token: Rails.application.config.zoho_workdrive_refresh_token,
        client_id: Rails.application.config.zoho_workdrive_client_id,
        client_secret: Rails.application.config.zoho_workdrive_client_secret,
        grant_type: 'refresh_token'
      }

      response = Net::HTTP.post_form(uri, params)

      parsed_response = parse_response(response)

      parsed_response["access_token"] || raise("Failed to retrieve access token: #{parsed_response['error_description']}")
    rescue StandardError => e
      raise "Error obtaining access token: #{e.message}"
    end

    #add folder inside organization
    def folder_in_folder(name, parent_folder_id)
      uri = URI("#{BASE_URL}/files")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@access_token}"
      request[CONTENT_TYPE] = APP_JSON

      body = {
        data: {
          attributes: {
            name: name,
            parent_id: parent_folder_id
          },
          type: "files"
        }
      }.to_json

      request.body = body

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      parse_response(response)
    end

    def parse_response(response)
      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise "Error parsing response: #{e.message}"
    end
  end
end
