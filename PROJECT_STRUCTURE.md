# 项目目录结构说明

本文档详细描述了 `lib` 目录下各个文件及文件夹的功能与职责，旨在帮助开发者快速理解项目结构。

## 目录概览

- **api/**: 网络请求层，负责与后端接口交互。
- **models/**: 数据模型层，定义应用中使用的数据结构及序列化逻辑。
- **pages/**: 页面层，包含应用的主要全屏视图。
- **providers/**: 状态管理层，使用 Provider 模式管理全局状态。
- **utils/**: 工具层，包含常量、日志记录等通用工具。
- **widgets/**: 组件层，包含可复用的 UI 组件和业务组件。
- **main.dart**: 应用程序入口文件，负责初始化应用配置、路由和全局 Provider。

## 详细文件说明

### 1. API (`lib/api/`)

负责处理所有的 HTTP 请求和 API 交互。

- **client.dart**: 封装 `ApiClient` 类，配置 Dio 实例，包括 Base URL、拦截器（Interceptor）和 Cookie 管理。
- **fishpi_api.dart**: 核心 API 业务类，封装了摸鱼派（FishPi）的各项接口方法，如登录、获取用户信息、文章列表、评论、聊天室消息等。

### 2. Models (`lib/models/`)

定义数据实体，通常包含 `fromJson` 和 `toJson` 方法。

- **article.dart**: 文章摘要模型，用于列表展示。
- **article_detail.dart**: 文章详情模型，包含完整的文章内容及相关元数据。
- **breezemoon.dart**: “清风明月”内容模型。
- **chat_message.dart**: 聊天室消息模型。
- **user.dart**: 用户信息模型，包含用户基本资料及扩展属性（如是否可关注）。
- **\*.g.dart**: `json_serializable` 生成的代码文件（自动生成，无需手动修改）。

### 3. Pages (`lib/pages/`)

应用的主要页面视图。

- **article_detail_page.dart**: 文章详情页。
  - 展示文章完整内容、作者信息。
  - 包含右侧目录导航（TOC）。
  - 集成评论列表及回复功能。
- **chat_room_page.dart**: 完整版聊天室页面。
  - 提供全屏的聊天体验。
  - 支持消息发送、图片上传、拖拽发送等高级功能。
- **home_page.dart**: 首页。
  - 包含顶部导航栏、侧边栏及主要内容区域。
  - 展示活跃度、签到榜、在线榜等仪表盘信息。
- **login_page.dart**: 登录页。
  - 处理用户名/密码输入及登录逻辑。
- **section_page.dart**: 分区通用页面。
  - 用于展示特定板块的内容列表（如“热门”、“关注”、“聊天室”等）。
- **user_profile_page.dart**: 用户个人主页。
  - 展示用户详细资料（头像、积分、在线状态等）。
  - 提供关注/取消关注功能。
  - 展示用户的文章、回帖等动态列表。

### 4. Providers (`lib/providers/`)

基于 Provider 的状态管理。

- **auth_provider.dart**: 认证状态管理。
  - 管理用户的登录状态、用户信息及 Token。
  - 提供登录（login）和登出（logout）方法。

### 5. Utils (`lib/utils/`)

通用工具类。

- **api_logger.dart**: API 日志工具，用于记录网络请求错误到本地文件。
- **constants.dart**: 全局常量定义，如 Base URL、User-Agent 等；也包含全局路由监听器 (`routeObserver`)。

### 6. Widgets (`lib/widgets/`)

可复用的 UI 组件。

- **article_comments.dart**: 文章评论列表组件，渲染评论树及回复功能。
- **article_content.dart**: 文章内容渲染组件，基于 `flutter_widget_from_html` 处理 HTML 内容。
- **breezemoon_widget.dart**: “清风明月”单条内容的展示组件。
- **chat_room.dart**: 聊天室组件，处理实时消息流的展示。
- **footer_bar.dart**: 页面底部栏。
- **header_bar.dart**: 页面顶部导航栏，包含 Logo、导航链接、搜索框及用户头像菜单。
- **home_dashboard.dart**: 首页仪表盘组件，展示签到榜、在线榜等统计信息。
- **hover_user_card.dart**: 鼠标悬停用户头像时显示的悬浮卡片容器，处理悬浮交互逻辑。
- **reply_bottom_sheet.dart**: 底部弹出的评论/回复输入框组件，支持 Emoji 和图片上传。
- **user_info_card.dart**: 用户信息卡片组件，展示用户头像、昵称、简介及关注按钮，支持乐观 UI 更新。
- **special_text/emoji_text.dart**: 自定义文本解析器，用于识别和渲染 Emoji 语法。
