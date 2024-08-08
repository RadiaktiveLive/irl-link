import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:irllink/src/core/resources/data_state.dart';
import 'package:irllink/src/core/utils/list_move.dart';
import 'package:irllink/src/data/repositories/streamelements_repository_impl.dart';
import 'package:irllink/src/domain/entities/settings.dart';
import 'package:irllink/src/domain/entities/settings/browser_tab_settings.dart';
import 'package:irllink/src/domain/entities/settings/chat_settings.dart';
import 'package:irllink/src/domain/entities/stream_elements/se_credentials.dart';
import 'package:irllink/src/domain/entities/stream_elements/se_me.dart';
import 'package:irllink/src/domain/entities/twitch/twitch_credentials.dart';
import 'package:irllink/src/domain/usecases/streamelements_usecase.dart';
import 'package:irllink/src/presentation/controllers/dashboard_controller.dart';
import 'package:irllink/src/presentation/controllers/obs_tab_view_controller.dart';
import 'package:irllink/src/presentation/controllers/realtime_irl_view_controller.dart';
import 'package:irllink/src/presentation/controllers/store_controller.dart';
import 'package:irllink/src/presentation/controllers/streamelements_view_controller.dart';
import 'package:irllink/src/presentation/controllers/tts_controller.dart';
import 'package:irllink/src/presentation/events/home_events.dart';
import 'package:irllink/src/presentation/widgets/tabs/obs_tab_view.dart';
import 'package:irllink/src/presentation/widgets/tabs/realtime_irl_tab_view.dart';
import 'package:irllink/src/presentation/widgets/tabs/twitch_tab_view.dart';
import 'package:split_view/split_view.dart';
import 'package:twitch_chat/twitch_chat.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../../../routes/app_routes.dart';
import '../../core/utils/constants.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../data/repositories/twitch_repository_impl.dart';
import '../../domain/usecases/settings_usecase.dart';
import '../../domain/usecases/twitch_usecase.dart';
import '../widgets/chats/chat_view.dart';
import '../widgets/tabs/streamelements_tab_view.dart';
import '../widgets/web_page_view.dart';
import 'chat_view_controller.dart';
import 'package:irllink/src/domain/entities/chat/chat_message.dart' as entity;

class HomeViewController extends GetxController
    with GetTickerProviderStateMixin {
  HomeViewController({required this.homeEvents});

  final HomeEvents homeEvents;

  SplitViewController? splitViewController = SplitViewController(
    limits: [null, WeightLimit(min: 0.12, max: 0.92)],
  );
  Timer? debounceSplitResize;

  // Tabs
  late TabController tabController;
  Rx<int> tabIndex = 0.obs;
  RxList<Widget> tabElements = <Widget>[].obs;
  RxList<WebPageView> iOSAudioSources = <WebPageView>[].obs;

  TwitchCredentials? twitchData;

  // StreamElements
  Rxn<SeCredentials> seCredentials = Rxn<SeCredentials>();
  Rxn<SeMe> seMe = Rxn<SeMe>();
  StreamelementsViewController? streamelementsViewController;

  // Chat input
  late TextEditingController chatInputController;
  RxList<Emote> twitchEmotes = <Emote>[].obs;

  // RealtimeIRL
  RealtimeIrlViewController? realtimeIrlViewController;

  // Emote picker
  RxBool isPickingEmote = false.obs;
  ObsTabViewController? obsTabViewController;

  late Rx<Settings> settings = const Settings.defaultSettings().obs;

  Timer? timerRefreshToken;
  Timer? timerKeepSpeakerOn;
  AudioPlayer audioPlayer = AudioPlayer();

  RxBool displayDashboard = false.obs;

  // Chats
  RxList<ChatView> channels = <ChatView>[].obs;
  Rxn<ChatGroup> selectedChatGroup = Rxn<ChatGroup>();
  int? selectedChatIndex;

  late TabController chatTabsController;
  Rxn<entity.ChatMessage> selectedMessage = Rxn<entity.ChatMessage>();

  @override
  void onInit() async {
    chatInputController = TextEditingController();
    chatTabsController = TabController(length: 0, vsync: this);

    if (Get.arguments != null) {
      TwitchTabView twitchPage = const TwitchTabView();
      tabElements.add(twitchPage);

      tabController = TabController(length: tabElements.length, vsync: this);

      twitchData = Get.arguments[0];

      await setStreamElementsCredentials();

      timerRefreshToken =
          Timer.periodic(const Duration(seconds: 13000), (Timer t) {
        homeEvents.refreshAccessToken(twitchData: twitchData!).then((value) => {
              if (value is DataSuccess) {twitchData = value.data}
            });

        if (seCredentials.value != null) {
          homeEvents
              .refreshSeAccessToken(seCredentials: seCredentials.value!)
              .then((value) => {
                    if (value is DataSuccess) {seCredentials.value = value.data}
                  });
        }
      });
    }
    await getSettings();

    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

    super.onInit();
  }

  @override
  void onClose() {
    debounceSplitResize?.cancel();
    timerRefreshToken?.cancel();
    timerKeepSpeakerOn?.cancel();
    super.onClose();
  }

  void onSplitResized(UnmodifiableListView<double?> weight) {
    if (debounceSplitResize?.isActive ?? false) debounceSplitResize?.cancel();
    debounceSplitResize = Timer(const Duration(milliseconds: 500), () {
      settings.value = settings.value.copyWith(
        generalSettings: settings.value.generalSettings?.copyWith(
          splitViewWeights: [weight[0]!, weight[1]!],
        ),
      );
      saveSettings();
    });
  }

  Future<void> setStreamElementsCredentials() async {
    DataState<SeCredentials> seCreds =
        await homeEvents.getSeCredentialsFromLocal();
    if (seCreds is DataSuccess) {
      seCredentials.value = seCreds.data;
      await setSeMe(seCredentials.value!);
    }
  }

  Future<void> setSeMe(SeCredentials seCreds) async {
    DataState<SeMe> seMeResult =
        await homeEvents.getSeMe(seCredentials.value!.accessToken);
    if (seMeResult is DataSuccess) {
      seMe.value = seMeResult.data;
    }
  }

  void lazyPutChat(ChatGroup chatGroup) {
    Get.lazyPut(
      () => ChatViewController(
        homeEvents: HomeEvents(
          twitchUseCase: TwitchUseCase(
            twitchRepository: TwitchRepositoryImpl(),
          ),
          settingsUseCase: SettingsUseCase(
            settingsRepository: SettingsRepositoryImpl(),
          ),
          streamelementsUseCase: StreamelementsUseCase(
            streamelementsRepository: StreamelementsRepositoryImpl(),
          ),
        ),
        chatGroup: chatGroup,
      ),
      tag: chatGroup.id,
    );
  }

  void reorderTabs() {
    List<BrowserTab> tabs = settings.value.browserTabs!.tabs;
    int diff = tabElements.length - tabElements.whereType<WebPageView>().length;
    tabs.forEachIndexed((index, tab) {
      if (tab.toggled) {
        // Find the index of the tab in the tabElements list
        int indexInTabs = tabElements.indexWhere(
          (element) => element is WebPageView && element.tab.id == tab.id,
        );
        // Move the tab to the correct index
        tabElements.move(indexInTabs, index + diff);
      }
    });
    tabElements.refresh();
  }

  Future<void> removeTabs() async {
    // Check if WebTabs have to be removed
    tabElements.whereType<WebPageView>().forEach((tabElement) {
      bool tabExist = settings.value.browserTabs!.tabs
          .any((settingsTab) => settingsTab.id == tabElement.tab.id);
      if (!tabExist) {
        tabElements.remove(tabElement);
      }
    });

    for (var tabElement in iOSAudioSources) {
      bool tabExist = settings.value.browserTabs!.tabs
          .any((settingsTab) => settingsTab.id == tabElement.tab.id);
      if (!tabExist) {
        iOSAudioSources.remove(tabElement);
      }
    }

    // Check if OBS have to be removed
    if (Get.isRegistered<ObsTabViewController>() &&
        !settings.value.isObsConnected!) {
      tabElements.removeWhere((t) => t is ObsTabView);
      obsTabViewController = null;
      await Get.delete<ObsTabViewController>();
    }

    // Check if StreamElements have to be removed
    if (Get.isRegistered<StreamelementsViewController>() &&
        (seCredentials.value == null)) {
      tabElements.removeWhere((t) => t is StreamelementsTabView);
      streamelementsViewController = null;
      await Get.delete<StreamelementsViewController>();
    }

    // Check if Realtime IRL have to be removed
    if (Get.isRegistered<RealtimeIrlViewController>() &&
        (settings.value.rtIrlPushKey == null ||
            settings.value.rtIrlPushKey!.isEmpty)) {
      tabElements.removeWhere((t) => t is RealtimeIrlTabView);
      realtimeIrlViewController = null;
      await Get.delete<RealtimeIrlViewController>();
    }
  }

  void addTabs() {
    bool isSubscribed = Get.find<StoreController>().isSubscribed();

    // Check if OBS have to be added
    if (obsTabViewController == null && settings.value.isObsConnected!) {
      obsTabViewController = Get.find<ObsTabViewController>();
      ObsTabView obsPage = const ObsTabView();
      tabElements.insert(1, obsPage);
    }

    // Check if StreamElements have to be added
    if (isSubscribed &&
        seCredentials.value != null &&
        streamelementsViewController == null) {
      streamelementsViewController = Get.find<StreamelementsViewController>();
      StreamelementsTabView streamelementsPage = const StreamelementsTabView();
      tabElements.insert(1, streamelementsPage);
    }

    // Check if Realtime IRL have to be added
    if (settings.value.rtIrlPushKey != null &&
        settings.value.rtIrlPushKey!.isNotEmpty &&
        realtimeIrlViewController == null) {
      realtimeIrlViewController = Get.find<RealtimeIrlViewController>();
      RealtimeIrlTabView realtimeIrlTabView = const RealtimeIrlTabView();
      tabElements.insert(1, realtimeIrlTabView);
    }

    // Check if WebTabs have to be added
    for (BrowserTab tab in settings.value.browserTabs!.tabs) {
      // first we check if the tab already exist
      bool tabExist = tabElements
          .whereType<WebPageView>()
          .any((element) => element.tab.id == tab.id);
      bool tabExistIniOSAudioSources =
          iOSAudioSources.any((element) => element.tab.id == tab.id);
      if (tabExist || tabExistIniOSAudioSources) {
        continue;
      }

      if (tab.toggled) {
        WebPageView page = WebPageView(tab);
        if (!tab.iOSAudioSource) {
          tabElements.add(page);
        } else {
          iOSAudioSources.add(page);
        }
      }
    }
  }

  Future generateTabs() async {
    await removeTabs();
    addTabs();
    reorderTabs();

    tabController = TabController(length: tabElements.length, vsync: this);
    if (tabIndex.value > tabElements.length - 1) {
      tabIndex.value = 0;
    }
    tabController.animateTo(tabIndex.value);
  }

  void generateChats() {
    if (twitchData == null) {
      return;
    }

    RxList<ChatView> groupsViews = RxList<ChatView>.from(channels);
    
    // 1. Find the groups that are in the groupsViews but not in the settings to remove them
    List<ChatGroup> settingsGroups = settings.value.chatSettings!.chatGroups;
    List<ChatGroup> groupsToRemove = groupsViews
        .where((groupView) => !settingsGroups.any((sGroup) => sGroup.id == groupView.chatGroup.id))
        .map((groupView) => groupView.chatGroup)
        .toList();
    for (var group in groupsToRemove) {
      ChatView groupView = groupsViews.firstWhere((g) => g.chatGroup.id == group.id);
      channels.remove(groupView);
    }

    // 2. Find the groups that are in the settings but not in the groupsViews to add them
    List<ChatGroup> groupsToAdd = settingsGroups
        .where((sGroup) => !groupsViews.any((groupView) => groupView.chatGroup.id == sGroup.id))
        .toList();
    for (var group in groupsToAdd) {
      ChatView groupView = ChatView(
        chatGroup: group,
      );
      lazyPutChat(group);
      channels.add(groupView);
    }

    chatTabsController = TabController(length: channels.length, vsync: this);
    if (channels.isEmpty) {
      selectedChatIndex = null;
      selectedChatGroup.value = null;
    }
  }

  void sendChatMessage(String message, String channel) {
    if (twitchData == null) return;

    TwitchChat twitchChat = TwitchChat(
      channel,
      twitchData!.twitchUser.login,
      twitchData!.accessToken,
      clientId: kTwitchAuthClientId,
    );
    twitchChat.connect();

    twitchChat.isConnected.addListener(() {
      if (twitchChat.isConnected.value) {
        twitchChat.sendMessage(message);
        twitchChat.close();
      }
    });

    chatInputController.text = '';
    selectedMessage.value = null;
    isPickingEmote.value = false;
  }

  void getEmotes() {
    ChatViewController? chatController =
        Get.find<ChatViewController>(tag: selectedChatGroup.value?.id);
    for (TwitchChat twitchChat in chatController.twitchChats) {
      List<Emote> emotes = List.from(twitchChat.emotes)
        ..addAll(twitchChat.emotesFromSets)
        ..addAll(twitchChat.thirdPartEmotes);
      twitchEmotes
        ..clear()
        ..addAll(emotes);
    }

    isPickingEmote.toggle();
  }

  void searchEmote(String input) {
    ChatViewController? chatController =
        Get.find<ChatViewController>(tag: selectedChatGroup.value?.id);

    for (TwitchChat twitchChat in chatController.twitchChats) {
      List<Emote> emotes = List.from(twitchChat.emotes)
        ..addAll(twitchChat.emotesFromSets)
        ..addAll(twitchChat.thirdPartEmotes);
      emotes = emotes
          .where(
            (emote) => emote.name.toLowerCase().contains(input.toLowerCase()),
          )
          .toList();
      twitchEmotes
        ..clear()
        ..addAll(emotes);
    }
  }

  void login() {
    Get.offAllNamed(Routes.login);
  }

  void saveSettings() {
    homeEvents.setSettings(settings: settings.value);
  }

  Future<DataState<Settings>> getSettings() async {
    DataState<Settings> settingsResult = await homeEvents.getSettings();
    if (settings is DataFailed) {
      return DataFailed('');
    }
    settings.value = settingsResult.data!;
    await applySettings(settingsResult.data!);
    return DataSuccess(settingsResult.data!);
  }

  Future applySettings(Settings settings) async {
    {
      generateTabs();
      generateChats();

      Get.find<DashboardController>();
      Get.find<TtsController>().initTts(settings);

      // DARK MODE
      if (!settings.generalSettings!.isDarkMode) {
        Get.changeThemeMode(ThemeMode.light);
      }

      // SPEAKER SETTING 
      if (settings.generalSettings!.keepSpeakerOn) {
        const path = "../lib/assets/blank.mp3";
        timerKeepSpeakerOn = Timer.periodic(
          const Duration(minutes: 5),
          (Timer t) async => await audioPlayer.play(AssetSource(path)),
        );
      } else {
        timerKeepSpeakerOn?.cancel();
      }

      // SPLIT VIEW
      splitViewController?.weights = settings.generalSettings!.splitViewWeights;
    }
  }
}
