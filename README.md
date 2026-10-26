# Azurion

Emulator Nintendo 3DS cho iOS, xây trên core [Azahar](https://github.com/azahar-emu/azahar).
Tập trung vào trải nghiệm chơi dòng game Pokémon (X/Y, ORAS, Sun/Moon, USUM) trên iPhone.

> **Pháp lý.** Azurion không kèm và không tải game, BIOS, firmware hay AES keys.
> Chỉ chạy bản dump **đã giải mã** từ máy 3DS của chính người dùng.
> Core được build với `ENABLE_BUILTIN_KEYBLOB=OFF`.
> Không dùng tên, logo hay hình ảnh Pokémon/Nintendo trong app và trên store.

## Kiến trúc

```
SwiftUI app (App/)                      thư viện game, màn chơi, gamepad ảo
        │  import AzurionCore
AzurionCore.framework (Bridge/)         API Objective-C, mọi C++ nằm ở đây
        │
Azahar core (external/azahar, submodule)
  ├─ CPU   dynarmic JIT (cần StikDebug), fallback interpreter
  ├─ GPU   Vulkan → MoltenVK → Metal, vẽ vào CAMetalLayer
  └─ Audio OpenAL → CoreAudio
```

- **App/**: Swift thuần. Không đụng C++. Gọi core qua `Emulator.shared`.
- **Bridge/**: Objective-C++. Mô phỏng theo frontend Android của Azahar
  (`src/android/app/src/main/jni`). Build bên trong cây CMake của Azahar.
- **patches/azahar/**: patch tối thiểu cho core, `bootstrap.sh` tự áp dụng.
  - `0001`: hook để CMake của Azahar build thư mục `Bridge/`.
  - `0002`: cho frontend iOS cung cấp MoltenVK (link tĩnh) cho renderer Vulkan.

## Yêu cầu

- Mac Apple Silicon, **Xcode 26** (cần macOS 15.6 trở lên) có iOS SDK.
- `brew install cmake ninja xcodegen`
- ~20 GB trống cho dependency và bản build.
- iPhone chạy iOS 17 trở lên. Muốn đủ tốc độ cần bật JIT bằng
  [StikDebug](https://stikdebug.org/). Simulator luôn có JIT.

## Build

```sh
scripts/bootstrap.sh          # submodule + patch + tạo Azurion.xcodeproj (chạy 1 lần)
scripts/build-core.sh         # build core → build/AzurionCore.xcframework (lâu ở lần đầu)
open Azurion.xcodeproj        # chọn Team trong Signing, chạy target Azurion
```

- Chỉ build cho máy thật: `scripts/build-core.sh device`. Chỉ simulator: `scripts/build-core.sh simulator`.
- Sửa gì trong `Bridge/` hoặc `external/azahar` thì chạy lại `build-core.sh` (build tăng dần).
- Sửa `project.yml` thì chạy lại `xcodegen generate`.

Game: import trong app (nút **+**) hoặc chép vào *Files › Azurion › Games*.
Save, config, log nằm ở *Files › Azurion › Data*.

## Làm việc với upstream Azahar

- Submodule đang trỏ vào repo gốc. Khi cần sửa core nhiều hơn, fork `azahar-emu/azahar`
  rồi `git submodule set-url external/azahar <fork>`.
- Giữ patch vào core càng ít càng tốt, để rebase lên upstream dễ dàng.
- Azahar có [chính sách AI](external/azahar/AI-POLICY.md): **không gửi code do AI viết lên upstream**
  (ngoại trừ đoạn ≤ ~5 dòng và có ghi rõ). Patch muốn đóng góp ngược phải do người viết.
- Azahar dùng GPLv3, nên Azurion cũng GPLv3 và phải công khai mã nguồn,
  kể cả khi phát hành bản có tính năng trả phí.

## Roadmap

| Phase | Mục tiêu | Trạng thái |
|---|---|---|
| 0 | Khung dự án: bridge, app SwiftUI, script build | ✅ code xong, chưa build thử |
| 1 | Boot Pokémon X trên iPhone: hình, tiếng, cảm ứng, gamepad ảo | ⏳ |
| 2 | JIT: hướng dẫn StikDebug, hỗ trợ iOS 26 TXM, progress shader cache, entitlement bộ nhớ | |
| 3 | Beta: layout ngang, tay cầm (GameController), save state, save manager (`.sav` cho PKHeX), bàn phím ảo của 3DS, cheat, cấu hình theo game, tăng tốc | |
| 4 | Phát hành: SideStore/AltStore, AltStore PAL, thử App Store, StoreKit cho bản Pro | |
| 5 | Trade/battle giữa hai iPhone qua multiplayer room | |

## License

GPLv3 or later, xem [LICENSE](LICENSE). Azahar: GPLv2+/GPLv3+, xem `external/azahar/LICENSE.txt`.
