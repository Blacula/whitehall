require "test_helper"

class HmrcAssetsControllerTest < ActionController::TestCase
  test "does not redirect hmrc asset requests that aren't made via the asset host" do
    asset_filesystem_path = File.join(Whitehall.hmrc_uploads_root, 'asset.txt')
    FileUtils.makedirs(Whitehall.hmrc_uploads_root)
    FileUtils.touch(asset_filesystem_path)

    request.host = 'not-asset-host.com'

    get :show, params: { path: 'asset', format: 'txt' }

    assert_response 200
  end
end
