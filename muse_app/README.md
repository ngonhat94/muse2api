# Muse Studio

Nhập cookie không copy/paste trên Chrome/Edge desktop: [hướng dẫn extension 1.1.0](../docs/BROWSER_ACCOUNT_IMPORT.md). Cần xác nhận từng lần, chỉ trên exact trusted domain; form thủ công vẫn giữ nguyên.

Flutter client cho backend muse2api, dùng BLoC và Clean Architecture.

## Phạm vi hiện tại

- Giao diện tiếng Việt, dark theme, sidebar desktop và navigation bar mobile.
- Kiểm tra server và Bearer API key bằng `GET /v1/models`, sau đó đọc vai trò/capability bằng `GET /v1/me`.
- Nhớ server và API key bằng `flutter_secure_storage`; mở app tự kiểm tra và kết nối lại.
- API key không lưu trong SharedPreferences. Ngắt kết nối vẫn giữ key; dùng **Quên API key đã lưu** để xóa.
- Chat nhiều lượt qua `POST /v1/chat/completions`, model `muse-spark`.
- Streaming SSE, dừng phản hồi, tạo cuộc trò chuyện mới và báo lỗi kết nối.
- Đổi/ngắt kết nối sẽ xóa hội thoại và kết quả ảnh để tránh lẫn dữ liệu giữa các server.
- Tạo ảnh qua `/v1/images/tasks`, chọn tỉ lệ, theo dõi tiến độ và hiển thị ảnh ngay trong app.
- Nhấn biểu tượng ảnh ở đầu màn hình chat để chuyển mô tả gần nhất sang mục Tạo ảnh.
- Tự kiểm tra tác vụ mỗi 3 giây; lỗi kết nối khi polling có thể thử lại mà không tạo task mới.
- Nhận ảnh dạng Base64 để tránh phụ thuộc URL media có hostname nội bộ phía server.
- Thêm ảnh tham chiếu từ thiết bị để chỉnh ảnh hoặc tạo video từ khung hình đầu tiên.
- Xem thumbnail, đổi thứ tự/xóa ảnh; hỗ trợ PNG/JPEG/WebP/GIF, tối đa 10 ảnh, 40 MiB/ảnh và 100 MiB tổng.
- Form báo lỗi ngay tại trường nhập, có focus vào mô tả còn thiếu và trạng thái lỗi cho ảnh tham chiếu.
- Theme dùng chung trong `app/studio_theme.dart`: nền tối trung tính, sắc nhấn sage, chữ phụ có tương phản rõ.

- Tạo video: chọn tỉ lệ/thời lượng, polling tiến độ, tiếp tục tác vụ từ lịch sử.
- Tác vụ: xem 100 tác vụ gần nhất, tự làm mới mỗi 5 giây khi mở trang, xem thành phẩm.
- Thư viện: ảnh/video trên server, xem trước và mở bằng trình duyệt.
- Tài khoản: nhập Cookie header, bật/tắt, kiểm tra phiên, cập nhật quota, xóa có xác nhận.
- Mobile: Chat/Ảnh/Video ở thanh dưới; Tác vụ/Thư viện/Tài khoản/Kết nối trong menu **Thêm**.

Chưa triển khai: tham chiếu video/audio/document, HEIC/AVIF. Video Windows/Linux dùng trình duyệt thay cho player nhúng.
Chat chỉ hiển thị văn bản; dùng mục **Tạo ảnh** để nhận và xem kết quả ảnh.
Backend Python vẫn chịu trách nhiệm Chromium/CDP và tài khoản Muse.

## Ảnh thành prompt (imageprompt.org)

Mở **Ảnh thành prompt** ở sidebar desktop hoặc **Thêm → Ảnh thành prompt** trên màn hình hẹp. Không cần server, tài khoản hoặc API key Muse. Thả đúng một tệp ảnh vào vùng chọn hoặc bấm **Chọn ảnh**; xem trước rồi bấm **Lấy prompt**. Kết quả là tiếng Anh, có thể chọn văn bản hoặc bấm **Sao chép prompt**. **Đổi ảnh/Xóa ảnh** loại bỏ kết quả cũ; phản hồi đến muộn không ghi đè ảnh mới.

- PNG/JPEG/WebP/GIF; tối đa **10 MiB** (giới hạn client riêng cho tính năng này). Kiểm tra kích thước trước khi đọc, kiểm tra lại byte thực, nhận MIME từ chữ ký và thử giải mã ảnh trước khi cho gửi. Không tin phần mở rộng tệp.
- Chọn/thả ảnh **không upload**. Chỉ nút **Lấy prompt** gửi toàn bộ ảnh gốc (bao gồm metadata nếu có) dạng Data URL tới `https://imageprompt.org/api/ai/prompts/image`; không tự thử lại. Xóa ảnh không thu hồi dữ liệu đã gửi cho bên thứ ba. Không dùng ảnh riêng tư hoặc nhạy cảm.
- Transport độc lập hoàn toàn với URL/key/cookie Muse. Không dùng cookie theo dõi người dùng, không lưu ảnh/prompt xuống preferences hoặc disk, không log payload/response. Dữ liệu chỉ ở RAM trong phiên; hãy Xóa ảnh trước khi rời máy. Sao chép là thao tác chủ động ghi prompt vào clipboard hệ thống.
- Dịch vụ bên thứ ba có thể đổi API, yêu cầu đăng nhập/tín dụng, giới hạn lượt hoặc từ chối nội dung. App hiển thị HTTP 401/402/403/429/451 và lỗi mạng/timeout/phản hồi sai; không tự đăng nhập hoặc né bảo vệ.
- Web chịu CORS của imageprompt.org: không thêm proxy, không hạ bảo vệ backend. Khi bị chặn hãy dùng bản desktop hoặc trang gốc. Kéo-thả dùng `desktop_drop`; file picker vẫn là đường thay thế bằng bàn phím.

Hợp đồng đã đối chiếu JS công khai `3298-0a6ff4512d5f78bd.js`: POST JSON với `base64Url`, `imageModelId: 0`, `language: "en"`; thành công phải có `prompt` dạng chuỗi. Một request trực tiếp không cookie bằng PNG tổng hợp màu peach 32×32 ngày 2026-11-12 trả **HTTP 200**, JSON `prompt` và `generatedAt`; không gửi ảnh cá nhân. OPTIONS preflight với Origin localhost trả HTTP 204 nhưng không có `Access-Control-Allow-Origin` hoặc `Access-Control-Allow-Headers`; bản web từ origin riêng hiện bị chặn theo CORS (không khẳng định mọi origin). Đây không phải kiểm thử chất lượng prompt với ảnh thực tế.

Kiểm thử tính năng: `flutter test test/image_prompt_repository_test.dart test/prompt_image_loader_test.dart test/image_prompt_cubit_test.dart test/image_prompt_page_test.dart test/widget_test.dart`. Fixture chỉ là ảnh tổng hợp; test không gọi dịch vụ thật.

## Văn bản thành prompt (Magic Enhance)

Mở **Văn bản thành prompt** cạnh **Ảnh thành prompt** ở sidebar hoặc **Thêm → Văn bản thành prompt** trên mobile, kể cả khi chưa kết nối Muse. Nhập mô tả, đọc thông báo đích gửi rồi bấm **Tạo prompt**; chỉ thao tác này gửi văn bản tới `https://imageprompt.org/api/ai/prompts/magic-enhance`. Nhập/sửa/xóa không tự gửi. Không dùng nội dung riêng tư hoặc nhạy cảm. Không gửi cookie, API key hay URL Muse; transport riêng, không tự retry, không lưu mô tả/kết quả. Clipboard chỉ được ghi khi bấm **Sao chép prompt**. **Xóa mô tả** xóa cả kết quả và bỏ qua phản hồi cũ, không thu hồi dữ liệu đã gửi.

App từ chối mô tả trống/toàn khoảng trắng, dùng giới hạn an toàn **4000 ký tự** riêng của client; chưa tìm thấy giới hạn dịch vụ trong JS đã đọc. Có loading, lỗi an toàn, kết quả chọn được và sao chép. Dịch vụ có thể yêu cầu đăng nhập/tín dụng, từ chối nội dung hoặc giới hạn lượt; app không né bảo vệ.

Đã đối chiếu JS công khai trang `/image-prompt-generator`: POST JSON đúng `{userPrompt, page: "image-prompt-generator"}`, nhận chuỗi `prompt`; không suy đoán ngôn ngữ đầu ra. Một lần gọi thật không cookie với ví dụ chú chó đen tai cụp trả **HTTP 200**, `prompt` tiếng Việt và `generatedAt` ngày 2026-11-12. OPTIONS từ `http://localhost:53123` trả **204**, không có Access-Control-Allow-Origin/Headers: web từ origin này hiện không dùng được do CORS, dù build thành công; dùng desktop hoặc trang gốc. Không thêm backend proxy. Xem `TEXT_PROMPT_VERIFICATION.md` cho lệnh, log và giới hạn kiểm chứng.

## Chuyển prompt và khôi phục tác vụ

- Cả hai công cụ prompt có **Dùng để tạo ảnh / Dùng để tạo video**. Chỉ chuyển văn bản sang form hiện có; không tự tạo, không upload ảnh và không gọi quota. Mô tả có sẵn phải được xác nhận trước khi thay; ảnh tham chiếu và tùy chọn form được giữ khi chuyển trang. Chưa kết nối vẫn điền được, sau đó người dùng chủ động kết nối/tạo.
- Khi backend trả mã tác vụ đang chạy, app lưu `{kind, id}` trong SharedPreferences, namespace SHA-256 theo URL server + API key. Không lưu khóa thô, cookie, prompt, reference image hoặc Base64. Đây không phải kho bí mật: task ID không được coi là credential. Credentials vẫn ở secure storage như trước.
- Mở app/kết nối lại đọc từng tác vụ đã lưu đúng server/credential bằng GET. Vào **Tác vụ** để xem mục **Khôi phục tác vụ đã lưu**, bấm **Kiểm tra** để đọc lại. App giữ được nhiều mã tác vụ; recovery kiểm tra một lượt, không chạy vòng polling nền vô hạn. Polling form đang tạo vẫn như trước. Recovery không có use case tạo, không gửi lại POST.
- Mất mạng, auth, phản hồi sai: giữ mã để kiểm tra lại, không kết luận tạo thất bại. HTTP 404 được ghi là không tìm thấy/có thể đã xóa, vẫn giữ mã vì chưa biết kết quả remote. Chỉ trạng thái terminal do server xác nhận mới loại khỏi danh sách pending; kết quả thành công xem trong **Thư viện**. Thông báo terminal recovery chỉ ở RAM đến lần tải lại.
- Đổi server/key cô lập kết quả và bỏ phản hồi cũ khỏi UI. Đóng app/ngắt kết nối không hủy công việc server. Xóa bản ghi backend cũng không đồng nghĩa hủy tạo.
- Dữ liệu lưu bị lỗi không bị ghi đè; nếu không lưu được mã mới, form vẫn giữ mã đã nhận, khóa tạo trùng và báo lỗi. Nếu app bị kill trước khi POST trả mã hoặc trước khi ghi storage xong, không thể khôi phục mã chưa được nhận/lưu: kiểm tra lịch sử server trước khi tạo lại. Không có generation POST tự động để bù.

Báo cáo và log: `PROMPT_RECOVERY_VERIFICATION.md`, `verification/prompt-recovery/`. iOS standalone vẫn **pending**, không thuộc đợt này.

## Chạy

```bash
flutter pub get
flutter run -d macos
# Hoặc: flutter run -d chrome
```

Nhập URL gốc của server (ví dụ `http://localhost:18610`), không thêm `/v1`,
và API key `MUSE2API_KEY` của backend. Server phải có tài khoản Muse khả dụng
để trả lời chat; kiểm tra kết nối chỉ xác nhận endpoint models và xác thực API.
Có hỗ trợ prefix reverse proxy, ví dụ `https://example.com/muse`.

- Android Emulator: `http://10.0.2.2:18610`.
- Thiết bị thật: dùng IP LAN/tên miền truy cập được, backend phải lắng nghe trên mạng.
- Flutter Web trên HTTPS cần backend HTTPS và CORS phù hợp.
- Android cho phép HTTP để dùng server tự host/LAN; nên dùng HTTPS qua mạng công cộng.
- iOS/macOS cho phép local networking; với server từ xa nên dùng HTTPS.
- Dừng chat đóng kết nối HTTP phía client. Thời điểm backend dừng công việc phụ thuộc
  vào việc backend phát hiện kết nối bị ngắt.

## Kiến trúc

```text
lib/
  app/                         # Composition root, theme, responsive shell
  core/
    errors/                    # Lỗi dùng chung, thông báo đã lược dữ liệu nhạy cảm
    network/                   # Bộ giải mã SSE và ánh xạ lỗi HTTP
  features/
    connection/
      domain/                  # Entity, repository contract, ConnectServer
      data/                    # HTTP, preferences, repository implementation
      presentation/            # ConnectionBloc và giao diện
    chat/
      domain/                  # ChatMessage, ChatRepository, SendMessage
      data/                    # DTO, HTTP/SSE, repository implementation
      presentation/            # ChatBloc và giao diện
    images/                    # domain/data/presentation cho tạo ảnh và polling
    videos/                    # tạo video, tiếp tục task và polling
    tasks/                     # lịch sử tác vụ trên server
    media/                     # thư viện ảnh/video
    accounts/                  # quản lý pool tài khoản
```

Chiều phụ thuộc: UI → BLoC → use case → repository contract.
Data triển khai contract của domain. `app/dependencies.dart` ghép các lớp cụ thể
bằng constructor injection. Domain không import Flutter, HTTP hoặc preferences;
BLoC dùng package `bloc`, widget dùng `flutter_bloc`.

BLoC xử lý gửi, nhận delta, hoàn tất, lỗi, dừng và reset. Mỗi luồng có generation
để bỏ qua phản hồi trễ từ hội thoại cũ. Transport đóng HTTP client khi cancel;
SSE xử lý UTF-8 bị chia gói, CRLF, comment, nhiều dòng data, `[DONE]`,
lỗi trong stream và kết nối kết thúc sớm. Không tự retry POST để tránh lặp tác vụ.

## Kiểm tra

```bash
flutter analyze
flutter test
# Unit tests không cần Flutter engine hoặc socket:
dart run test test/core/sse_decoder_test.dart test/core/storage_failure_test.dart test/features/chat_bloc_test.dart test/features/chat_transport_test.dart test/features/connection_bloc_test.dart test/features/image_bloc_test.dart test/features/image_transport_test.dart test/features/video_bloc_test.dart test/features/next_phases_transport_test.dart test/features/admin_bloc_test.dart test/features/reference_images_test.dart test/features/chat_history_test.dart test/features/proxy_settings_test.dart
# Test transport qua HTTP thật với server giả local, không gọi Muse:
dart run test test/features/api_transport_test.dart
```

Các bài kiểm tra không sử dụng cookie Muse và không tiêu tốn quota.
Widget test kiểm tra màn hình cấu hình ở kích thước mobile/desktop.
Local HTTP test đối chiếu request/response với handler trong `../app.py`;
không thay thế kiểm thử tích hợp với backend Muse thật.

## Kết quả kiểm tra

Đợt cập nhật upstream v1.6.10: `8a3dab9` → `b60f474`.

- `flutter analyze`: không có vấn đề.
- `flutter test --reporter expanded`: **281 tests pass**.
- `flutter build macos --debug` và `flutter build web`: thành công.
- Giữ nguyên app/theme/prompt tools/lưu media và cấu hình native; thêm thông báo an toàn cho lỗi composer chưa gửi của backend mới, không tự gửi lại POST.
- Backend đã chạy 31 script kiểm thử độc lập và các fixture Chrome composer/upload/media. Web-admin upstream còn lỗi overflow ở viewport tiếng Anh 320px; không phải lỗi layout Flutter.
- Chưa thử Muse thật, Keychain/OS dialogs hoặc đóng gói lại engine Python/browser. Bản `flutter build` không tự cập nhật engine đã cài.

SHA đầy đủ, backup đã kiểm tra, lệnh/log và giới hạn: [UPSTREAM_UPDATE_VERIFICATION.md](UPSTREAM_UPDATE_VERIFICATION.md).

## Lưu thông tin kết nối

Sau khi nâng cấp từ bản chỉ lưu key trong RAM, cần nhập lại key một lần.
Dừng ứng dụng và chạy lại đầy đủ sau khi thêm plugin, thay vì chỉ hot reload.
Server và key được lưu cùng một record để tránh dùng nhầm key với server khác.
Trên macOS/iOS plugin dùng Keychain; entitlements macOS đã được cấu hình.
Flutter Web cần HTTPS hoặc localhost để dùng WebCrypto. Linux cần libsecret và
libjsoncpp theo hướng dẫn của flutter_secure_storage.
Không có dữ liệu nào được khôi phục từ cookie hoặc file cấu hình backend.

## Luồng video, tác vụ và tài khoản

- Video gửi `POST /v1/videos` đúng một lần, sau đó chỉ `GET /v1/videos/{id}`.
  Khi mất phản hồi POST, app yêu cầu kiểm tra lịch sử trước khi gửi lại vì backend
  video hiện không hỗ trợ Idempotency-Key. Có thể tiếp tục theo dõi video đang chạy
  từ mục Tác vụ, kể cả sau khi đóng/mở lại app.
- Tiến độ video là các mốc backend quan sát được, không phải phần trăm thời gian còn lại.
- Task/thư viện/tài khoản đọc từ server hiện tại, không lưu snapshot trên thiết bị.
  Đổi kết nối xóa dữ liệu đang hiển thị và bỏ qua mọi response cũ.
- App chỉ chấp nhận URL media capability ngắn hạn do backend trả về, buộc đúng
  server/prefix và filename. App không đưa API key vào URL phát media.
- Video phát trong app trên Web/Android/iOS/macOS; Windows/Linux mở bằng trình duyệt.
  Định dạng phát được còn phụ thuộc codec của thiết bị và trình duyệt.
- Cookie nhập tài khoản chỉ được giữ tạm trong form và gửi tới backend đã chọn;
  form xóa sau khi nhập thành công hoặc đổi kết nối. App không ghi cookie xuống disk.
- Ô **Cookie string** nhận một chuỗi `hatch_sess=...; hatch_vml=...`, hoặc danh sách
  nhiều dòng dạng `acc-01 | hatch_sess=...; hatch_vml=...`. Với danh sách, tên được
  lấy từ từng dòng; form đếm số tài khoản và báo dòng sai trước khi gửi. Có thể
  ẩn/hiện nội dung cookie. Nếu chưa xác nhận được kết quả nhập, tải lại danh sách
  trước khi thử lại để tránh thêm trùng.
- Kiểm tra phiên/quota có thể mất thời gian do backend phải mở trang Muse.
  Nếu kiểm tra không xác nhận được phiên, app không báo thành công.
- Xóa tài khoản cần xác nhận, và chỉ xóa bản ghi trong pool backend.

Sau khi thêm video_player/url_launcher, cần dừng app rồi `flutter pub get` và chạy lại
đầy đủ để đăng ký plugin native. Chỉ hot reload không đủ.

## Ảnh tham chiếu và quy ước giao diện

Frontend tuân theo ba skill người dùng yêu cầu: UI UX Pro Max, Taste và Impeccable;
quy ước được ghi tại `../AGENTS.md`. Áp dụng các nguyên tắc phù hợp Flutter:
nhất quán về theme, nhãn thao tác rõ ràng, phản hồi tại chỗ, bố cục responsive và
trạng thái loading/error/empty. Không thay app native bằng một trang landing HTML.

Ảnh tham chiếu được chọn qua system file picker, nhận diện MIME bằng chữ ký tệp,
kiểm tra kích thước trước khi đọc/gửi và giữ trong bộ nhớ. `ReferenceCubit` gọi use
case để chọn/kiểm tra tệp; BLoC tạo media nhận snapshot bất biến. Dữ liệu được gửi
qua `images` dưới dạng Data URL, đúng thứ tự đã chọn. Chỉnh ảnh dùng cùng tác vụ
`/v1/images/tasks` với ảnh tham chiếu để giữ luồng polling. Đổi nội dung hoặc thứ tự
ảnh đổi Idempotency-Key; thử lại cùng dữ liệu sau lỗi POST giữ nguyên key.

Ảnh đầu tiên của video là khung hình chính; các ảnh tiếp theo là tham chiếu.
Ảnh và thumbnail được xóa khỏi màn hình khi thay kết nối, không lưu trong preferences.
macOS đã thêm quyền đọc tệp do người dùng chọn. Sau nâng cấp file_selector cần dừng
và chạy lại app đầy đủ. Chưa xác nhận system picker trên thiết bị thật, tạo/chỉnh
media bằng Muse thật hoặc kiểm tra trực quan bản UI bằng ảnh chụp trong môi trường này.

## Proxy theo tài khoản

Trong **Tài khoản → Proxy tài khoản**, nhập địa chỉ HTTP/SOCKS5/SOCKS5H và thông tin
xác thực ở các trường riêng. **Kiểm tra proxy** chỉ gọi endpoint kiểm tra; **Lưu proxy**
mới thay đổi cấu hình trên server. Kết quả tách việc kết nối proxy khỏi việc xác nhận
phiên Muse và không cam kết tác vụ tạo media thành công.

Khi địa chỉ/tên đăng nhập không đổi, để trống mật khẩu sẽ giữ mật khẩu đã lưu trên
server. Nếu đổi một trong hai và dùng username, phải nhập lại mật khẩu. Có lựa chọn
xóa mật khẩu và gỡ proxy. Mật khẩu không được đọc từ backend, ghi log hay lưu trên
thiết bị. Tài khoản đang bận trả lỗi và không bị app báo lưu thành công.

## Lịch sử chat trên thiết bị

Nhấn biểu tượng **Lịch sử trò chuyện** trong màn hình chat để mở lại/xóa từng cuộc
hoặc bắt đầu cuộc mới. Tạo cuộc mới giữ bản lưu của cuộc cũ. Xóa cần xác nhận và chỉ
xóa bản lưu trên thiết bị. Bản này bắt đầu lưu các cuộc mới; không phục hồi được
những cuộc từ bản cũ chỉ tồn tại trong RAM.

Lịch sử dùng adapter flutter_secure_storage riêng, không dùng record chứa API key.
Dữ liệu phân vùng theo hash của cặp server/API key; đổi server hoặc đổi API key không
mang lịch sử sang phiên mới. Key/API không được ghi vào JSON lịch sử hoặc tên record.
Khóa được xoay sẽ tạo phân vùng mới; không tự chuyển dữ liệu của khóa cũ.

Ghi dữ liệu được tuần tự hóa để lưu/xóa đồng thời không ghi đè lẫn nhau. App lưu khi
gửi, hoàn tất/dừng phản hồi, đổi cuộc/đổi server và khi app chuyển nền; trong lúc
stream có checkpoint khoảng 2 giây. Tắt cưỡng bức không bảo đảm checkpoint cuối được
lưu. Lỗi đọc không tự ghi đè dữ liệu cũ; lỗi ghi báo tại chỗ và giữ nội dung trong RAM.
Giới hạn 2 MiB JSON mỗi phân vùng; không tự xóa cuộc cũ. Khi đầy, xóa bớt cuộc rồi thử
lưu lại. Đăng xuất/quên API key không tự xóa các bản lưu chat; xóa trong màn hình lịch sử.

Kiểm thử lịch sử dùng repository lưu trữ trong bộ nhớ, không chứng minh persistence
Keychain trên thiết bị. Regression tests bao gồm: Stop giữ câu trả lời dở và loại bỏ
chunk đến muộn; đổi server trong lúc hủy stream/xóa cuộc chat không được làm trống
nội dung của server mới, kể cả khi hai phân vùng có cùng ID cuộc chat.
Chưa xác nhận UI trực quan, proxy/Muse thật hoặc lưu lịch sử bằng Keychain trên thiết bị.
Signing/Keychain macOS hiện được hoãn để người dùng cấu hình; không tắt bảo vệ lưu trữ
hoặc chuyển API key sang lưu dạng rõ để vượt qua bước này.

## Lưu ảnh/video về máy

Trên desktop (macOS/Windows/Linux), bấm **Lưu về máy** dưới ảnh vừa tạo hoặc trong phần xem trước video. Trong **Thư viện** mở một tệp; trong **Tác vụ** bấm **Xem kết quả** để có cùng nút lưu. App mở hộp thoại **Save As** của hệ điều hành để chọn tên/vị trí và xác nhận ghi đè; không cần mở trình duyệt và không tự tải khi tạo xong. Hủy hộp thoại không phải lỗi. Trong lúc tải có số KB đã nhận và **Hủy lưu**; thành công chỉ báo sau khi ghi xong.

Ảnh hiện có trong RAM được ghi nguyên byte, nhận đuôi PNG/JPEG/WebP/GIF từ chữ ký. Tệp thư viện/video được tải theo URL capability ngắn hạn do backend trả về cho đúng `/v1/media/{name}` của kết nối đã chọn, hỗ trợ prefix reverse proxy; API key/cookie không nằm trong URL và app không theo redirect. URL thiếu `cap`, sai host/prefix/tên hoặc có tham số khác đều bị từ chối. Capability hết hạn hoặc bị thu hồi cần tải lại task/thư viện để nhận URL mới.

App ghi tệp tạm cạnh đích rồi đổi tên sau khi tải đủ/flush, không để tệp cuối hỏng khi mất mạng, hủy hoặc đổi kết nối. Timeout chờ mạng 30 giây; giới hạn tổng tải mạng 20 phút. Dọn tạm là best-effort nếu ổ đích bị tháo/mất quyền; tắt cưỡng bức có thể còn thư mục `.muse-save-*`. Ghi đè do người dùng xác nhận trong picker, không có khóa chống chương trình khác sửa cùng tệp. Windows/Linux chưa được chạy build/manual tại đây; lỗi rename không được báo thành công.

Web/mobile hiện hiển thị giới hạn hỗ trợ desktop thay vì giả báo đã lưu; thao tác mở bằng trình duyệt vẫn giữ cho media có URL. Không đổi signing/entitlements. Sandbox macOS hiện tắt sẵn; nếu bật sandbox trong bản phân phối sau này cần người dùng cấu hình quyền ghi tệp đã chọn. Chưa kiểm thử tương tác hộp thoại OS/codec/Muse thật; kiểm thử dùng fixture tổng hợp, không gọi Muse hoặc tiêu quota. Chi tiết kết quả và log: [MEDIA_SAVE_VERIFICATION.md](MEDIA_SAVE_VERIFICATION.md).

## Lọc thư viện và lưu nhiều tệp

Thư viện có bộ lọc **Tất cả / Ảnh / Video**, tìm tên không phân biệt hoa thường,
**Mới nhất** (ngày chưa rõ xếp cuối, thứ tự bằng ngày giữ nguyên) và **Thứ tự server**.
Đổi tìm kiếm/bộ lọc/thứ tự sẽ bỏ chọn để tránh xóa hoặc lưu các tệp đang bị ẩn.

Chọn tệp rồi bấm **Lưu N tệp vào thư mục** trên macOS/Windows/Linux: chọn thư mục
một lần, tải lần lượt, hiển thị KB nhận của tệp hiện tại, hỗ trợ **Hủy lưu**.
Kết quả ghi rõ từng tệp đã lưu / lỗi / bỏ qua / hủy; giữ các tệp đã thành công,
không tự thử lại. Tên trùng hoặc tệp đích đã tồn tại được bỏ qua, không ghi đè
có chủ ý. Vẫn có cửa sổ race giữa kiểm tra tồn tại và rename nếu chương trình
khác đồng thời tạo cùng tên; không dùng đây như khóa liên tiến trình.
Web/mobile báo giới hạn desktop. Chi tiết kiểm thử và giới hạn còn lại:
[LIBRARY_BATCH_VERIFICATION.md](LIBRARY_BATCH_VERIFICATION.md).

## Quản lý media trong Flutter

Thư viện hỗ trợ xóa một tệp hoặc chọn nhiều tệp để xóa hàng loạt, luôn xác nhận
trước khi gửi lệnh. Chỉ tên tệp hợp lệ thuộc thư viện hiện tại được phép xóa.
Kết quả hàng loạt hiển thị số tệp server xác nhận đã xóa và lỗi từng phần đã được
ẩn chi tiết nhạy cảm; không mặc định tất cả tệp đã chọn đều được xóa thành công.
Sau thao tác, app tải lại thư viện. Nếu tải lại thất bại, cần làm mới thành công
trước khi xóa tiếp. Phản hồi/hộp xác nhận của server cũ không tác động server mới.
Kiểm thử tự động bao gồm repository, bloc và widget; chưa xóa media trên server thật.

## macOS: không lưu được API key

App hiển thị lỗi ghi credential sau khi đã kiểm tra API server thành công. Thông báo
mới chỉ đưa mã OSStatus dạng số lên UI, không đưa exception message/details hoặc key.
MissingPluginException yêu cầu dừng và chạy lại app đầy đủ; mã -34018 chỉ tới entitlement
Keychain. Adapter lịch sử dùng cùng cách ánh xạ lỗi.

Bản debug đã kiểm tra đang ký ad-hoc, không có TeamIdentifier và không có entitlement
Keychain trong binary, dù file nguồn có keychain-access-groups rỗng. Cần kiểm tra trong
Xcode: mở `macos/Runner.xcworkspace`, chọn target Runner → Signing & Capabilities,
chọn Team của người dùng, dùng automatic signing và bật Keychain Sharing. Không điền
Team ID tùy ý vào project. Sau đó dừng app, `flutter clean`, `flutter pub get` và
`flutter run -d macos`. Chưa xác nhận được OSStatus thực tế của lỗi ảnh chụp; nếu lỗi
còn tiếp diễn, lấy mã số từ thông báo mới để phân biệt nguyên nhân.

## Desktop độc lập

Bản desktop có lựa chọn **Dùng trên máy này**: chạy engine đi kèm, nhập cookie ở
mục Tài khoản và dùng Muse mà không cần cấu hình server/API key. Chế độ server
riêng và key đã lưu vẫn được giữ. Cần build bundle đầy đủ bằng
`python tools/build_desktop.py` từ gốc repo; `flutter build` riêng không kèm engine.
Xem [hướng dẫn desktop](../docs/DESKTOP.md) để build, chạy phát triển và xem phạm vi
kiểm thử cùng giới hạn phân phối. Cookie ở chế độ này được lưu trong dữ liệu
engine trên thiết bị, không chỉ giữ tạm trong form.

Trong tab **Kết nối Muse**, nút **Cài đặt engine** tự chuẩn bị engine và kết nối
khi hoàn tất. Cách cài từ app cần Internet, Python 3.11+ và bộ cài/source đi kèm;
hiển thị tiến trình, hỗ trợ hủy và giữ nguyên server/key đã lưu.
