# Thiết kế luồng ủng hộ nhẹ nhàng cho ứng dụng miễn phí

Tài liệu dùng lại cho các ứng dụng khác · 05/10/2026

Cập nhật tên ngày 06/10/2026: ứng dụng tham chiếu nay là **VidSavie**, phiên bản 2.2.43 (145). Các ví dụ mang tên VideoFetch Flow bên dưới ghi lại luồng được thiết kế trước khi đổi tên; nguyên tắc và hành vi không thay đổi.

## 1. Mục tiêu

Giúp người dùng biết họ có thể ủng hộ tác giả sau khi nhận được giá trị từ ứng dụng, nhưng không làm họ cảm thấy phải trả tiền, bị làm phiền hoặc bị chặn thao tác.

Nguyên tắc xuyên suốt: **ứng dụng vẫn hữu ích và sử dụng bình thường dù người dùng không ủng hộ**. Không dùng sự ủng hộ làm điều kiện để tải, cập nhật, đóng app hay tiếp tục công việc.

Đây là hướng dẫn thiết kế rút ra từ VideoFetch Flow, không phải kết luận rằng cách này làm tăng doanh thu. Chưa có thử nghiệm người dùng hoặc số liệu chuyển đổi.

## 2. Ba vị trí phù hợp

| Vị trí | Vai trò | Cách trình bày |
|---|---|---|
| Cài đặt → Giới thiệu | Nơi đầy đủ và dễ tìm | Một khối nhỏ: tiêu đề thân thiện, 1–2 câu, nút ❤️ Ủng hộ |
| Thanh thao tác hoặc thanh trạng thái | Lối tắt luôn sẵn có | Nút nhỏ cạnh các chỉ số, không nổi bật hơn chức năng chính |
| Hộp xác nhận thoát | Lời cảm ơn cuối phiên, nếu app cần xác nhận thoát | Lời nhắn ngắn phía trên; đường phân cách; nhóm nút rõ ràng phía dưới |

Trong VideoFetch Flow, nút nhanh nằm bên phải mục Hoàn tất; trang Giới thiệu có liên kết Ko-fi; hộp xác nhận thoát có ba lựa chọn.

Không cần áp dụng cả ba vị trí cho mọi app. Với công cụ nhỏ mà việc thoát không có rủi ro mất công việc, ưu tiên hai vị trí đầu. Hộp thoại mỗi lần thoát là một đánh đổi: người dùng phải thêm một thao tác, dù nội dung rất lịch sự.

## 3. Công thức viết lời mời

Chỉ cần bốn ý, khoảng 40–70 từ, điều chỉnh theo ngôn ngữ:

1. Chào hoặc cảm ơn người dùng.
2. Giới thiệu ngắn: tác giả tạo công cụ hữu ích và chia sẻ miễn phí.
3. Nêu tác động cụ thể: sự ủng hộ giúp tiếp tục cải thiện và cập nhật.
4. Nói rõ hoàn toàn tự nguyện.

Không kể chuyện dài, không nhấn mạnh khó khăn của tác giả để tạo cảm giác có lỗi. Chỉ nói “dùng AI” nếu điều đó thực sự phù hợp với cách làm và câu chuyện của tác giả; đây không phải thành phần bắt buộc.

### Mẫu tiếng Việt

Chào bạn! 👋

Mình tạo những ứng dụng nhỏ, hữu ích và chia sẻ miễn phí. Nếu app giúp bạn tiết kiệm thời gian, một chút ủng hộ trên Ko-fi sẽ tiếp thêm động lực để mình cải thiện nó. Hoàn toàn tùy bạn — cảm ơn bạn đã sử dụng! ❤️

### Mẫu tiếng Anh

Hi there! 👋

I build small, useful apps and share them for free. If this app saved you time, a small Ko-fi tip helps me keep improving it. No pressure — thanks for using it! ❤️

### Mẫu cực ngắn trong Cài đặt

Thích ứng dụng này?

Nếu app hữu ích với bạn, hãy cân nhắc ủng hộ tác giả trên Ko-fi. Hoàn toàn tự nguyện. Cảm ơn bạn! ❤️

Tên nút nên là **Ủng hộ / Support** để dễ hiểu. “Love”, “Yêu thích” có thể khiến người dùng tưởng đây là đánh giá hoặc thêm vào danh sách yêu thích; “Tips” phù hợp khi đối tượng đã quen với thuật ngữ này.

## 4. Luồng xác nhận thoát

Phần trên: icon app, lời chào, lời nhắn ngắn. Sau đó là câu hỏi rõ ràng: “Bạn muốn thoát [Tên app]?” Nếu đang có công việc, giải thích việc thoát sẽ ảnh hưởng thế nào bằng thông tin đúng với app.

Phần dưới: đường phân cách mảnh và ba nút. Các nút hành động chính phải dễ nhận biết; nút Ủng hộ là lựa chọn phụ, không thay thế nút thoát.

| Lựa chọn | Kết quả bắt buộc |
|---|---|
| Có, thoát / Yes, quit | Đóng hộp thoại và cho phép thoát |
| Không, ở lại / No, stay | Đóng hộp thoại, giữ app hoạt động |
| ❤️ Ủng hộ / Support | Mở trang ủng hộ trong trình duyệt, không thoát app |
| Esc | Giữ app hoạt động |
| Enter | Theo lựa chọn an toàn đã xác định; VideoFetch Flow chọn ở lại |

VideoFetch Flow hiện đóng hộp thoại khi mở Ko-fi và giữ app chạy. Nếu người dùng quay lại và muốn thoát, họ chọn thoát lần nữa. Không tự thoát sau khi mở trang, không suy đoán rằng người dùng đã thanh toán.

Nếu app vẫn tự động xử lý công việc khi hộp thoại mở, cần nói rõ điều đó khi phù hợp. “Ở lại” không đồng nghĩa tạm dừng hay hủy công việc.

### Những lối thoát cần phân biệt

- Nút nguồn, lệnh Quit và Cmd-Q: đi qua cùng một cơ chế xác nhận.
- Đóng cửa sổ: giữ nguyên quy ước của app; với app chạy nền, không được bất ngờ biến thành thoát toàn bộ.
- Force Quit hoặc tín hiệu kết thúc tiến trình: không đảm bảo hiện được hộp thoại; không cố ngăn người dùng buộc dừng app.
- Tắt máy, đăng xuất, cập nhật tự động: cần kiểm tra riêng trên từng nền tảng. Không để lời mời ủng hộ cản quá trình hệ thống hoặc cập nhật.

## 5. Thiết kế thị giác và khả năng tiếp cận

- Dùng trái tim đỏ nhỏ làm dấu hiệu nhất quán, kèm chữ; không chỉ dùng icon.
- Giữ lời nhắn dễ đọc, màu chữ đủ tương phản ở cả giao diện sáng và tối.
- Hộp thoại gọn, không có ảnh quảng cáo, bộ đếm, hiệu ứng nhấp nháy hay danh sách mức tiền dài.
- Không cắt chữ nút hoặc bản dịch dài. Ưu tiên câu ngắn và chiều rộng đủ dùng.
- Dùng hộp thoại chuẩn của nền tảng khi phù hợp để có hỗ trợ bàn phím và trình đọc màn hình.
- Tách nội dung khỏi hành động bằng khoảng cách hoặc đường phân cách mảnh.
- Với popup trình duyệt, chỉ một thành phần sở hữu cuộn: khung ngoài giới hạn chiều cao, header/footer không co, phần nội dung co được và cuộn. Không tạo cuộn lồng nhau hoặc giấu cả thanh cuộn lẫn nội dung.
- Riêng popup extension Chrome tự đo kích thước từ nội dung: tránh giới hạn chiều cao bằng `100vh` hoặc các đơn vị viewport tương tự. Viewport ban đầu có thể rất nhỏ, làm popup co thành một dải. VideoFetch Flow dùng body cao 600px, khung ngoài không cuộn, nội dung flex co được và tự cuộn; kiểm tra trực tiếp sau Reload vẫn cần thiết.

## 6. Giảm phiền khi áp dụng cho app khác

Không hiện lời mời khi tải thất bại, khi có lỗi cookie, khi người dùng đang sửa lỗi hoặc ở lần mở đầu chưa dùng được chức năng nào. Những thời điểm đó người dùng chưa nhận được giá trị hoặc đang cần trợ giúp.

Nếu thêm một lời nhắc chủ động, nên có “Không nhắc lại” hoặc thời gian nghỉ đủ dài. Không bật lại ngay sau khi người dùng từ chối. Đây là khuyến nghị cho app khác, **chưa phải tính năng đã có trong VideoFetch Flow**.

Đặc biệt cân nhắc tùy chọn tắt lời mời khi thoát nếu nhận phản hồi rằng hộp thoại gây phiền. Xác nhận thoát bảo vệ công việc và lời mời ủng hộ là hai mục đích khác nhau; không bắt buộc phải gắn chúng mãi với nhau.

## 7. Ranh giới kỹ thuật và riêng tư

- Liên kết chỉ mở khi người dùng bấm. Dùng địa chỉ HTTPS cố định đã kiểm tra, như `https://ko-fi.com/atu1202` trong VideoFetch Flow.
- Không tự gửi lịch sử sử dụng, cookie, đường dẫn file, lỗi tải hay thông tin tài khoản trong URL ủng hộ.
- Không tự mở Ko-fi ở lần chạy đầu hoặc sau mỗi thao tác thành công.
- Không nhúng đăng nhập/thẻ thanh toán vào hộp thoát; để nền tảng thanh toán xử lý trong trình duyệt.
- Không hứa “không mất phí”, “rút tiền ngay” hoặc “không cần tài khoản” nếu chưa kiểm tra điều kiện hiện hành của nền tảng.
- Nếu mở trình duyệt thất bại, app vẫn ở lại; có thể cho người dùng sao chép liên kết để mở thủ công.
- Không đổi trạng thái người dùng thành “đã ủng hộ” chỉ vì họ bấm liên kết.
- Tách luồng ủng hộ khỏi bộ tải, cập nhật công cụ, giấy phép và dữ liệu người dùng.

## 8. Bản địa hóa

Dịch toàn bộ lời nhắn, câu hỏi và nút theo ngôn ngữ đang chọn trong app. Nếu chưa có bản dịch, dùng một ngôn ngữ dự phòng thống nhất thay vì trộn nửa Việt nửa Anh.

Đừng dịch tên thương hiệu Ko-fi hoặc tên app. Viết tự nhiên theo từng ngôn ngữ, không dịch máy móc “tip” thành một từ khó hiểu. Kiểm tra tiếng Đức/Pháp thường dài hơn, tiếng Nhật/Hàn cần ngắt dòng hợp lý.

VideoFetch Flow có nội dung hộp thoát cho Anh, Việt, Trung, Tây Ban Nha, Pháp, Đức, Bồ Đào Nha, Nhật và Hàn. Đủ khóa dịch không đồng nghĩa đã được người bản ngữ duyệt chất lượng.

## 9. Checklist trước khi phát hành

- [ ] Không ủng hộ vẫn sử dụng đầy đủ chức năng đã hứa.
- [ ] Lời nhắn ngắn và có câu nhấn mạnh tự nguyện.
- [ ] Thoát thật sự thoát; ở lại không thoát.
- [ ] Support chỉ mở đúng trang, không tự thoát hay tự xác nhận thanh toán.
- [ ] Enter/Esc không vô tình làm mất công việc.
- [ ] Nhấn thoát liên tiếp không tạo nhiều hộp thoại.
- [ ] Đóng cửa sổ và Cmd-Q giữ đúng ý nghĩa riêng.
- [ ] Kiểm tra app có công việc đang chạy, app rảnh, đăng xuất và quy trình cập nhật.
- [ ] Kiểm tra cả sáng/tối, từng ngôn ngữ, bàn phím và trình đọc màn hình.
- [ ] Nội dung dài vẫn đọc được; popup chỉ có một vùng cuộn.
- [ ] Link không kèm dữ liệu riêng tư; lỗi mở trình duyệt không làm app thoát.
- [ ] Giữ bản sao lưu trước triển khai; không xem test mã nguồn là xác nhận giao diện thực tế.

## 10. Tham chiếu triển khai VideoFetch Flow

Các đường dẫn dưới đây tương đối với thư mục mã nguồn; bản tài liệu này có thể lưu độc lập.

- `Sources/VideoBatchDownloader/SettingsView.swift`: khối ủng hộ trong Giới thiệu.
- `Sources/VideoBatchDownloader/ContentView.swift`: nút trái tim bên cạnh Hoàn tất và nút thoát.
- `Sources/VideoBatchDownloader/AppText.swift`: nội dung giao diện liên quan.
- `Sources/VideoBatchDownloader/QuitConfirmation.swift`: hộp xác nhận, bản dịch và xử lý ba lựa chọn.
- `Sources/VideoBatchDownloader/VideoBatchDownloaderApp.swift`: gắn delegate xác nhận thoát.
- `ChromeExtension/popup.css`: một vùng cuộn cho popup.
- `Tests/Extension/branding.test.js`, `quit-and-scroll.test.js`: kiểm tra liên kết, cấu trúc và hợp đồng an toàn trong nguồn.

Bản tham chiếu: 2.2.42 (144). Bản 2.2.41 từng qua kiểm tra nguồn nhưng ảnh người dùng cho thấy popup bị co do giới hạn `100vh`; bản 2.2.42 đã bỏ phụ thuộc viewport và qua build/kiểm thử lại. Điều này minh họa rằng test mã nguồn không thay thế kiểm tra giao diện thực tế. Bố cục sau sửa và thao tác hộp thoại vẫn cần người dùng xác nhận; không ghi nhận thử nghiệm thanh toán hoặc kết quả tài trợ.
