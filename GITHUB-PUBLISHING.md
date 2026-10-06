# Đưa VidSavie lên GitHub

Mã nguồn 2.2.42 đã tải lên repository **Private** `Atu96/vidsavie` ngày 06/10/2026: https://github.com/Atu96/vidsavie. Nhánh mặc định `main`, remote `origin`. Chưa chuyển Public, chưa chọn LICENSE và chưa đăng bản DMG lên Releases. Các bước Desktop bên dưới là hướng dẫn cho lần thiết lập mới; kho hiện tại đã được tạo bằng GitHub CLI.

## Mã nguồn

1. Cài [GitHub Desktop](https://desktop.github.com/), đăng nhập tài khoản GitHub của bạn.
2. Chọn **File → Add Local Repository**, chọn thư mục `VideoBatchDownloader` của dự án này. Nếu chưa có repository, chọn tạo repository tại thư mục đó.
3. Kiểm tra danh sách Changes trước khi commit: không đưa cookie, hồ sơ trình duyệt, token, lịch sử tải hay dữ liệu cá nhân lên. `.gitignore` đã loại thư mục build, dist và một số file tạm; không thay thế việc kiểm tra thủ công.
4. Commit bản đầu. Chọn **Publish repository**, tên `vidsavie`. Có thể giữ private để kiểm tra trước; bỏ **Keep this code private** khi bạn thật sự muốn công khai.
5. Chọn giấy phép trước khi gọi dự án là mã nguồn mở. MIT là một lựa chọn cho mã do bạn sở hữu; giấy phép của công cụ bên thứ ba vẫn phải được giữ riêng. Chưa tự thêm LICENSE vì bạn chưa chọn.

Mô tả gợi ý: **A local-first macOS video downloader with a browser companion, resumable downloads, and built-in media tools.**

## Bản cài cho người dùng

Trong trang repository chọn **Releases → Draft a new release**. Tạo tag tương ứng phiên bản đã kiểm thử, ví dụ `v2.2.40`, tiêu đề `VidSavie 2.2.40`.

Đính kèm DMG arm64 và file SHA-256 do `Scripts/build-dmg.sh` tạo trong `dist/`. Không đưa DMG vào lịch sử mã nguồn. GitHub tự tạo gói mã nguồn cho tag. Ghi rõ hỗ trợ Apple Silicon; bản hiện tại ký ad-hoc, chưa được Apple notarize. Không yêu cầu người dùng vô hiệu hóa Gatekeeper toàn hệ thống.

Chỉ phát hành sau khi test, build, kiểm tra chữ ký và mount-test DMG thành công. Giữ các thông báo giấy phép của công cụ nhúng. Bản 2.2.40 hiện đã build và kiểm thử app; chưa tạo DMG mới trong lượt này.

Nút Sponsor dùng Ko-fi của bạn: https://ko-fi.com/atu1202.

Tham khảo chính thức: [đưa dự án hiện có lên GitHub bằng Desktop](https://docs.github.com/en/desktop/adding-and-cloning-repositories/adding-an-existing-project-to-github-using-github-desktop), [tạo Release](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository), [thêm giấy phép](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/adding-a-license-to-a-repository).
