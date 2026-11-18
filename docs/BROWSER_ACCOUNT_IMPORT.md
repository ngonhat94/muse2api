# Nhập tài khoản từ trình duyệt (extension 1.1.0)

## Cài đặt một lần

1. Trên **Chrome hoặc Edge desktop**, tải `/admin/extension` từ server đang kết nối (endpoint yêu cầu Bearer auth; có thể dùng nút tải extension của admin UI hiện có), hoặc lấy thư mục `extension/` từ nhánh/PR này. Giải nén vào thư mục cố định. Không dùng bản 1.0.2.
2. Mở `chrome://extensions` hoặc `edge://extensions`, bật Developer mode, chọn **Load unpacked**, chọn thư mục chứa `manifest.json` (`muse2api-extension` nếu dùng ZIP). Sau cập nhật chọn Reload. Không nhập private key; manifest chỉ chứa public key để giữ ID `lloaecnfmnmampknhgnpagabengejlaj` ổn định giữa máy.
3. Đăng nhập muse.ai trong **cùng browser profile**. Tải lại Muse Studio Web, kết nối bằng key người dùng, mở Tài khoản Muse → **Nhập tài khoản từ trình duyệt**.
4. Cửa sổ riêng của extension hiển thị origin trang yêu cầu và URL POST chính xác. Kiểm tra cả hai và chọn **Cho phép nhập một lần** trong 90 giây. Hủy/đóng cửa sổ không đọc cookie, không POST. Không có bước copy/paste cookie/key.
5. Khi thành công app tải lại danh sách. Nếu mất kết nối/timeout, tải lại danh sách trước khi thử lại; không tự retry POST. Import không xác minh phiên bằng Muse/quota và không bảo đảm phiên vẫn hợp lệ.

Mobile, Safari, Firefox, native Flutter desktop và incognito/profile khác không hỗ trợ cầu nối này. Form nhập thủ công và popup extension cũ vẫn dùng được. Popup thủ công xin quyền host theo URL người dùng nhập; API key không còn lưu vào chrome.storage (bản cũ được xóa khi mở popup).

## Exact trust configuration

Frontend mặc định duy nhất: `https://muapp-3d6.pages.dev` (project hostname xác định từ check Cloudflare Pages của main 4518ea3). Không cho `*.pages.dev` hoặc preview subdomain. Backend exact allowlist: `https://18610-agq6gp235jkrlip6hyszdk5ctm.instabox.tech` (defaultServerUrl hiện có trong client_config_repository.dart) và `https://muse.dntrip.xyz` (docs/DEPLOYMENT.md). Không tự tin cậy server do caller gửi, localhost/private IP hoặc URL HTTP. URL prefix được hỗ trợ trên backend đã allowlist; userinfo/query/fragment/port khác/encoded path bị từ chối. Fetch dùng redirect:error, không gửi ambient cookies, không đọc/trả nội dung response.

Nếu quản trị viên đổi domain: review và sửa **cùng lúc** `extension/manifest.json` (externally_connectable.matches và host_permissions), `extension/import_policy.js` (origins và backend origin), và `muse_app/lib/features/accounts/data/browser_import_web.dart` (frontend origin), chạy test, build và reload extension. Không thêm wildcard. Extension unpacked có ID ổn định qua public key trong manifest, không phải bản Chrome Web Store đã ký. Nếu phân phối Store, thay ID trong adapter bằng ID Store thực và build lại; không đoán ID.

## Security and lifecycle

- Không content script/postMessage: trang chỉ gọi chrome.runtime.sendMessage đến ID cố định. Cookie chỉ ở extension và POST trực tiếp tới backend đã allowlist. Response chỉ gồm id và mã trạng thái cố định.
- Prepare không chứa API key; popup extension tin cậy phải duyệt từng lần trước khi app gửi key. Commit giữ key transient, không storage/log. Không capability backend mới: dùng key của session đang hoạt động; `/admin/accounts` hiện tại tự gắn owner từ principal, payload không có owner/user ID.
- Bind nonce ngẫu nhiên 256-bit với origin, top-level tab, document ID; TTL 90s; consume trước cookie read/POST, chống lặp. Navigation/tab close hoặc disconnect/app page dispose trước commit hủy yêu cầu. Service-worker restart mất pending, fail closed. Nonce cache giới hạn 4096; hết giới hạn cần reload extension, không tự reset replay cache.
- Khi POST đã bắt đầu, logout không thể thu hồi bytes đã gửi. App bỏ mọi kết quả stale và không cập nhật danh sách session mới. Không tự retry bất kể kết quả. Origin/backend allowlist không bảo vệ trước chính origin hoặc backend đã bị chiếm quyền; quản trị viên phải duy trì TLS/DNS và bảo vệ API key như mọi tính năng web khác.
- Host allowlist cố định ngăn caller chỉ tới private/local URL; không có DNS resolver trong extension để kiểm tra DNS rebinding. Tin cậy DNS/TLS của backend đã ghim là ranh giới triển khai, không nhận domain tùy ý.

## Verification

Đã chạy trong PR: Flutter 360 tests pass; analyze --no-fatal-infos pass (65 informational diagnostics, chủ yếu Material deprecation từ Flutter 3.50); release web build pass; 43 backend guarded scripts pass (6 browser/socket scripts loại trừ có chủ đích); toàn bộ JS regressions pass. `python tools/browser_import_smoke.py` đã chạy Chromium unpacked thật với synthetic httpOnly cookie và fake upload trong service worker: ID, external ping, popup origin/target, duyệt, payload/auth/redirect và response không cookie đều pass. Không login Muse thật, không gửi POST tới backend thật. Screenshot được chụp nhưng image-analysis tool bị unavailable; chưa có manual device/Edge validation.


`node tests/test_browser_import.cjs` chạy worker/policy bằng synthetic Chrome API và synthetic cookies, không Muse thật. Flutter `test/features/browser_import_test.dart` kiểm tra session capture, duplicate, cancel/timeout, stale disconnect/dispose, missing extension, uncertain outcome. Full suite, analyze và release web build phải chạy trước PR. Browser smoke dùng Chromium unpacked + route fixture nếu có; không cần đăng nhập Muse và không tạo account thật. Graphify không có trong môi trường verifier; graph persisted không được coi là source truth cho thay đổi này.
