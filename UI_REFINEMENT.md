# 本轮界面更新

- 保留最初的米白默认主题与五主题切换，统一字体、金额层次、输入框、按钮和卡片。
- 中文与数字字体内置，不依赖手机品牌默认字体或在线下载；字体及授权文件合计约 4.5MiB。
- 快捷记账改为金额输入、分类图标、账户选择；备注与图片折叠。其他表单采用相同底部编辑面板。
- 账户与流水金额按屏幕宽度调整排布；预留项目有独立余额和进度；主题选择提供样式预览。
- 删除首页口号和重复引导，缩短操作名；必要公式和说明收起，错误和超支状态保留。
- 日期选择器使用中文，减少动画设置同时作用于编辑面板。

资金模型、账本数据格式、账户/预算的动态配置及原始目标记录保持兼容。本轮未添加联网或云同步。

## 已做与待做的验证

本地完成：全部 Dart 文件语法树检查；五主题核心颜色对比度计算；字体字形覆盖、字重、授权文件检查；Android 配置脚本与签名生成/恢复检查；交付 ZIP 内容与 CRC 校验。

本地没有 Flutter/Dart SDK，因此 **未执行 flutter analyze、flutter test 或 APK 编译，也没有本轮真机截图**。新增测试已接入 GitHub Actions，是否通过须以运行结果为准。

Actions 的 `warm-ledger-ui-review` 附件会在 UI 测试实际执行并输出图片后提供暖色/夜间五页面截图。它们来自 Flutter 测试渲染，仍需手机确认键盘、字体、触控与系统栏效果。

## 更新现有 GitHub 仓库

上传本项目的 `lib`、`assets`、`test`、`pubspec.yaml`、`analysis_options.yaml` 及更新后的 `.github/workflows/build-apk.yml`。也可上传完整项目内容；仓库根目录应直接有 `pubspec.yaml`，避免多套一层文件夹。尤其不要漏掉新增的 `lib/editor.dart`、`lib/theme_picker.dart` 和 `assets/fonts`。

如果 GitHub 上传界面不接收 `.github` 文件夹，打开仓库已有 `.github/workflows/build-apk.yml`，点编辑按钮，用交付包中的同名文件内容替换并提交。不要把文件夹改成 `.GitHub`。

随后从 Actions 发起新一次 Run workflow。已经保存签名 secrets 的更新继续使用原签名，不勾 `first_build`；从未生成过签名的首次打包才勾选它。重跑旧任务不会自动读取新代码或改变输入。
