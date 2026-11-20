# Muse Studio desktop độc lập

App desktop có chế độ **Dùng trên máy này**. Flutter khởi động engine Python đã
đóng gói, engine dùng Chromium đi kèm để làm việc với Muse. Người dùng không cần
cài Python, Chrome hay tự chạy muse2api. Vẫn cần Internet và cookie Muse còn hiệu
lực; tính năng và quota phụ thuộc tài khoản Muse.

## Sử dụng

1. Mở bản desktop đầy đủ, chọn **Bắt đầu trên máy này** nếu chưa tự khởi động.
2. App mở **Tài khoản**, dán cookie đơn hoặc nhiều dòng `tên | cookie` và nhập.
3. Chuyển sang Trò chuyện, Tạo ảnh hoặc Tạo video.

Cài mới ưu tiên chạy trên máy này. Nếu trước đó đã lưu server riêng, app tiếp tục
khôi phục server đó. Lựa chọn kết nối thành công gần nhất được nhớ cho lần sau.
Mục **Dùng server riêng** vẫn giữ nguyên server/key; khóa engine tạm thời không
được ghi đè lên thông tin này. Dừng phiên giữ dữ liệu, cookie và kết quả để lần
sau dùng lại. Đổi chế độ sẽ xóa dữ liệu phiên đang hiển thị như khi đổi server.

## Cài engine ngay trong app

Trong **Kết nối Muse → Dùng trên máy này**, chọn **Cài đặt engine**. App hiển thị
các bước chuẩn bị, cài dependency, tải Chromium, tạo engine và kiểm tra. Khi
thành công, app tự kết nối rồi mở Tài khoản để nhập cookie. Có thể hủy; app chờ
dừng tiến trình cài trước khi cho kết nối/cài lại. Không cần mở Terminal.

Cách cài này cần **Internet và Python 3.11 trở lên** trên máy. App tìm bộ cài ở
source project khi chạy phát triển, hoặc `desktop_setup` trong bản đóng gói mới.
Nếu thiếu Python/bộ cài, app báo rõ; nút không tự cài Python hay yêu cầu quyền
quản trị. Bản desktop đầy đủ vẫn có engine đi kèm để dùng ngay.

Engine được tạo trong workspace tạm và kiểm tra trước khi thay bản cũ; nếu thay
thất bại thì khôi phục bản cũ. Các file nguồn được sao chép theo danh sách cố định,
không sao chép `.env`, cookie, key hay dữ liệu tài khoản. Engine cài từ nút nằm ở
`desktop-runtime/current` cạnh thư mục `engine` của ứng dụng và được tìm lại sau
khi mở app. Dữ liệu cookie/media vẫn dùng thư mục `engine` riêng, không bị bộ cài
thay thế. Hai cửa sổ không được cài cùng lúc vào một vị trí.

## Build bản desktop đầy đủ

Build trên chính hệ điều hành và kiến trúc CPU cần phân phối. Yêu cầu Flutter
phù hợp với pubspec, Python 3.11+, toolchain Flutter desktop và mạng để tải gói.
Từ thư mục gốc repository, trong một Python virtualenv riêng đã kích hoạt:

```sh
python -m pip install -r desktop/requirements-build.txt
python tools/build_desktop.py
```

Nếu Flutter không nằm trong PATH:

```sh
python tools/build_desktop.py --flutter /duong/dan/flutter/bin/flutter
```

Script tải Chromium, đóng gói engine bằng PyInstaller, build Flutter release,
rồi ghép chúng thành app đầy đủ trong `dist/desktop/`. Không copy `.env`, dữ liệu
accounts, cookie, API key, media hoặc profile của người build. Giữ nguyên toàn bộ
bundle khi phân phối, không chỉ lấy file executable.

- macOS: `dist/desktop/muse_app.app` (hoặc tên app đã cấu hình trong Xcode).
- Windows/Linux: `dist/desktop/MuseStudio/`.

Các thư viện hệ thống của Flutter/Chromium vẫn phải có trên phiên bản OS được
hỗ trợ; riêng Linux cần chuẩn bị browser dependencies ở máy build/test. Script
chưa tạo DMG/MSI/DEB và chưa chạy kiểm thử trên cả ba OS. App macOS dùng ad-hoc
signing để chạy kiểm tra cục bộ; bản phân phối cần ký các executable/framework
lồng nhau bằng Developer ID, cấu hình hardened runtime phù hợp và notarization.
Windows cần quy trình ký bản phát hành riêng. Bản macOS này tắt App Sandbox để
chạy engine/trình duyệt con; hướng phân phối hiện tại là app tải trực tiếp,
không phải Mac App Store.

## Chạy phát triển

Cách khởi động từ source, tại gốc repository:

```sh
python3 tools/run_desktop.py
```

Windows có thể dùng `python` thay `python3`. Lệnh tạo virtualenv build riêng trong
`build/desktop/venv`, cài dependency, tải Chromium, đóng gói engine rồi chạy Flutter
với đường dẫn engine đúng. Không khởi chạy Flutter nếu chưa chuẩn bị engine xong.
Các lần sau tái sử dụng bundle nếu fingerprint nguồn và nền tảng vẫn khớp; thiếu
browser hoặc nguồn engine thay đổi sẽ build lại. Cần mạng ở lần chuẩn bị đầu tiên.

```sh
python3 tools/run_desktop.py --flutter /duong/dan/flutter/bin/flutter
python3 tools/run_desktop.py --prepare-only
python3 tools/run_desktop.py --rebuild-engine
```

`flutter run` hoặc `flutter build` riêng lẻ không tự ghép engine. Lỗi **Bản cài này
chưa có engine desktop** nghĩa là thiếu bundle, không phải cookie sai. Có thể
chọn **Cài đặt engine** trong app để chuẩn bị. Dùng lệnh chuẩn bị trên khi phát triển,
hoặc build bundle đầy đủ để phân phối. App cũng phân biệt thiếu browser, engine
đang chạy ở cửa sổ khác và lỗi quyền ghi; không hiển thị exception chứa dữ liệu
nhạy cảm từ tiến trình con.

## Vòng đời và dữ liệu

- Flutter truyền khóa ngẫu nhiên cho mỗi phiên qua stdin. Không có khóa trong
  argv, thông báo ready, preferences hoặc log do lớp desktop tạo ra.
- Engine tự bind HTTP trên `127.0.0.1` với cổng do OS cấp, giữ socket đó cho
  Uvicorn. App xác minh `/v1/models` bằng khóa phiên trước khi báo đã kết nối.
- Đóng app đóng pipe stdin; engine yêu cầu dừng Uvicorn và Chromium mà nó sở hữu.
  App chủ động dừng engine khi ngắt kết nối/chuyển server. Engine dừng bất ngờ
  khiến app ngắt phiên và hiển thị thao tác khởi động lại, không tự gửi lại tác vụ.
- Khóa file ngăn hai engine dùng chung thư mục dữ liệu. Chỉ dừng các tiến trình
  app đã khởi tạo; desktop không tái sử dụng CDP của một Chrome đang chạy khác.
- Cookie được lưu bởi backend hiện có trong `data/accounts.json`; đây là dữ liệu
  JSON, **chưa mã hóa bằng Keychain/DPAPI**. Trên Unix, thư mục riêng có mode 0700
  và file mới theo umask 0077. Windows dùng thư mục dữ liệu của người dùng.
- Thư mục mặc định: macOS `~/Library/Application Support/MuseStudio/engine`,
  Windows `%LOCALAPPDATA%/MuseStudio/engine`, Linux
  `$XDG_DATA_HOME/muse-studio/engine` hoặc `~/.local/share/muse-studio/engine`.
- Desktop chặn trang quản trị HTML, helper extension và endpoint cập nhật/push
  source của server. Các luồng API tài khoản/chat/ảnh/video vẫn tái sử dụng engine.
- Android/iOS/Web vẫn dùng chế độ server; không chạy tiến trình desktop.

## Phạm vi xác minh

Kiểm thử BLoC và mô phỏng pipe/HTTP kiểm tra chuyển chế độ, giữ key, hủy khởi
động, khóa phiên, xác minh endpoint, EOF và phản hồi khi engine thoát. Kiểm thử
Python kiểm tra bootstrap, vị trí browser, quyền thư mục và khóa instance.
Đây không thay thế việc mở app đã đóng gói và kiểm thử Muse thật trên từng OS.

Tham khảo đóng gói:
- https://pyinstaller.org/en/stable/usage.html
- https://pyinstaller.org/en/stable/runtime-information.html
- https://playwright.dev/python/docs/browsers
