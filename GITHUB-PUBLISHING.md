# Đưa VidSavie lên GitHub

Repository **Public** hiện tại: https://github.com/Atu96/vidsavie, được người dùng cho phép công khai ngày 06/10/2026. Nhánh mặc định `main`, remote `origin`. Mã nguồn do dự án sở hữu dùng GPL-3.0-or-later; công cụ bên thứ ba giữ giấy phép riêng. Release `v2.2.44` có DMG arm64 và SHA-256, nhưng việc xác minh nguồn tương ứng của các binary nhúng còn chưa hoàn tất; đọc `LICENSING-AUDIT.md` trước khi tiếp tục phân phối. Các bước Desktop bên dưới là hướng dẫn cho lần thiết lập mới.

## Mã nguồn

1. Cài [GitHub Desktop](https://desktop.github.com/), đăng nhập tài khoản GitHub của bạn.
2. Chọn **File → Add Local Repository**, chọn thư mục `VideoBatchDownloader` của dự án này. Nếu chưa có repository, chọn tạo repository tại thư mục đó.
3. Kiểm tra danh sách Changes trước khi commit: không đưa cookie, hồ sơ trình duyệt, token, lịch sử tải hay dữ liệu cá nhân lên. `.gitignore` đã loại thư mục build, dist và một số file tạm; không thay thế việc kiểm tra thủ công.
4. Commit bản đầu. Chọn **Publish repository**, tên `vidsavie`. Có thể giữ private để kiểm tra trước; bỏ **Keep this code private** khi bạn thật sự muốn công khai.
5. Giấy phép đã chốt cho nguồn gốc của VidSavie: GPL-3.0-or-later, xem LICENSE/COPYRIGHT. Không tự áp giấy phép này cho app khác hoặc công cụ bên thứ ba. Có LICENSE không có nghĩa bộ cài đã tuân thủ đầy đủ nghĩa vụ cung cấp nguồn.

Mô tả gợi ý: **A local-first macOS video downloader with a browser companion, resumable downloads, and built-in media tools.**

## Bản cài cho người dùng

Trong trang repository chọn **Releases → Draft a new release**. Tạo tag tương ứng phiên bản đã kiểm thử, ví dụ `v2.2.40`, tiêu đề `VidSavie 2.2.40`.

Đính kèm DMG arm64 và file SHA-256 do `Scripts/build-dmg.sh` tạo trong `dist/`. Không đưa DMG vào lịch sử mã nguồn. GitHub tự tạo gói mã nguồn cho tag. Ghi rõ hỗ trợ Apple Silicon; bản hiện tại ký ad-hoc, chưa được Apple notarize. Không yêu cầu người dùng vô hiệu hóa Gatekeeper toàn hệ thống.

Chỉ phát hành sau khi test, build, kiểm tra chữ ký và mount-test DMG thành công. Giữ các thông báo giấy phép của công cụ nhúng. DMG 2.2.44 đã qua các bước này; Release nằm tại https://github.com/Atu96/vidsavie/releases/tag/v2.2.44. Kho đã Public nên người ngoài có thể truy cập nguồn và Release.

Nút Sponsor dùng Ko-fi của bạn: https://ko-fi.com/atu1202.

Tham khảo chính thức: [đưa dự án hiện có lên GitHub bằng Desktop](https://docs.github.com/en/desktop/adding-and-cloning-repositories/adding-an-existing-project-to-github-using-github-desktop), [tạo Release](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository), [thêm giấy phép](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/adding-a-license-to-a-repository).
