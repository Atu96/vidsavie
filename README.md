# VideoFetch Flow

Ứng dụng nhỏ trên thanh menu macOS để tải video, âm thanh và ảnh. Bạn có thể dán nhiều liên kết vào app, hoặc dùng nút tải ngay trên trang đang xem qua tiện ích Chrome.

Mình làm app này với sự hỗ trợ của AI, trước hết để dùng cho công việc của mình, rồi chia sẻ miễn phí cho ai cũng cần. App vẫn đang được cải thiện; nếu gặp lỗi, bạn cứ báo lại nhé.

## App làm được gì?

- Tải từ YouTube, Douyin, Bilibili, X, Facebook, Instagram và một số trang khác. Mức hỗ trợ tùy trang và nội dung.
- Xếp nhiều liên kết vào hàng đợi, tải lần lượt từng mục.
- Giữ phần đã tải khi lượt tải bị gián đoạn, để có thể thử tiếp nếu nguồn còn cho phép.
- Lưu lịch sử, mở file hoặc tìm lại file trong Finder.
- Cắt video, chuyển đổi định dạng và xử lý âm thanh bằng các công cụ đi kèm.
- Đổi ngôn ngữ và giao diện sáng/tối; đồng bộ cài đặt với tiện ích trình duyệt.

Bản cài có sẵn yt-dlp, FFmpeg và FFprobe. Người dùng không cần cài Homebrew để dùng app; công cụ hỗ trợ có thể được cập nhật trong Cài đặt.

## Tải và cài đặt

Bản đóng gói hiện dành cho **Mac Apple Silicon (M1, M2, M3… / arm64)**. Chưa có bản cài cho Mac Intel.

**Hiện kho này mới có mã nguồn, chưa có bộ cài trong [Releases](https://github.com/NgocTu96/videofetch-flow/releases).** Khi có DMG, bạn mở file và kéo VideoFetch Flow vào Applications. Nếu muốn tự build, xem phần cuối README.

### Về cảnh báo của macOS

Mình chưa có ngân sách đăng ký Apple Developer Program, nên bản cài hiện chưa có chữ ký Developer ID và chưa được Apple notarize. macOS có thể hiện cảnh báo khi bạn mở app.

Mình ghi rõ ở đây để bạn biết trước khi cài. Chỉ mở bản tải từ nguồn bạn tin tưởng; không cần tắt Gatekeeper cho toàn bộ máy. Nếu chưa yên tâm, bạn có thể xem mã nguồn trước hoặc chờ bản phát hành sau.

## Nút tải trên Chrome

1. Mở Cài đặt trong app, tìm mục Tiện ích trình duyệt và chọn cài cho Chrome. App sẽ mở trang quản lý tiện ích cùng thư mục chứa `ChromeExtension`.
2. Bật **Developer mode** trong `chrome://extensions`.
3. Chọn **Load unpacked** rồi chọn thư mục `ChromeExtension` đi kèm app.
4. Giữ app chạy nền và mở lại trang video để dùng nút tải.

Sau khi cập nhật app có thay đổi tiện ích, bấm **Reload** trên thẻ VideoFetch Flow trong trang Extensions. Tiện ích chưa được phát hành trên Chrome Web Store. Luồng cài đặt chính hiện được kiểm tra trên Chrome; Firefox chưa được kiểm chứng tương đương.

## Một vài điều cần biết

Các trang video thay đổi khá thường xuyên. Một video tải được không có nghĩa mọi video trên cùng trang đều tải được; một số nội dung cần phiên đăng nhập, bị giới hạn khu vực hoặc không còn khả dụng.

App xử lý lượt tải và media trên máy Mac của bạn, nhưng vẫn cần kết nối với trang nguồn để lấy nội dung và tải công cụ khi cập nhật. Không có tài khoản dịch vụ riêng của app.

Chỉ tải nội dung bạn có quyền tải và sử dụng. Nếu gặp lỗi, dùng nút chép log trong app để báo lại; nhớ bỏ thông tin riêng tư trước khi chia sẻ, và đừng gửi cookie hay mật khẩu.

## Nếu bạn muốn ủng hộ

Nếu app giúp bạn bớt vài thao tác mỗi ngày, bạn có thể [mời mình một ly cà phê trên Ko-fi](https://ko-fi.com/atu1202). Mình sẽ dùng sự ủng hộ đó để duy trì và làm app tốt hơn.

Không ủng hộ cũng không sao. Cảm ơn bạn đã dùng app và góp ý cho mình. ❤️

## Build từ mã nguồn

Cần môi trường build Swift 6, macOS SDK và Node.js/npm để chạy kiểm thử. Mã nguồn đặt mức macOS tối thiểu là 13; việc chạy thực tế trên từng phiên bản macOS vẫn cần được kiểm tra.

Từ thư mục dự án:

```sh
./Scripts/test.sh
./Scripts/build-app.sh
```

App được tạo tại `.build/app/VideoFetch Flow.app`. Có thể tạo DMG arm64 bằng `./Scripts/build-dmg.sh`; kết quả nằm trong `dist/`. Bước đóng gói tải và kiểm tra các công cụ hỗ trợ, nên cần mạng. Kiểm thử tự động không tải video thật và không đọc cookie trình duyệt.

Thông tin về công cụ đi kèm: [Portable tool notices](Resources/ThirdParty/PORTABLE_TOOLS.md). Kho hiện chưa chọn giấy phép cho mã nguồn của app; giấy phép của các công cụ bên thứ ba được giữ riêng.

Nếu sửa nguồn, đọc [CHECKPOINT](CHECKPOINT.md), [SYSTEM-MAP](SYSTEM-MAP.md) và [ARCHITECTURE](ARCHITECTURE.md) trước. Các tài liệu này ghi lại cấu trúc app, lỗi đã xử lý và những phần cần giữ tương thích.
