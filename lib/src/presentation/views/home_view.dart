import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:irllink/routes/app_routes.dart';
import 'package:irllink/src/domain/entities/tabbar/web_page.dart';
import 'package:irllink/src/presentation/controllers/home_view_controller.dart';
import 'package:irllink/src/presentation/widgets/chat_view.dart';
import 'package:irllink/src/presentation/widgets/obs_tab_view.dart';
import 'package:irllink/src/presentation/widgets/twitch_tab_view.dart';
import 'package:irllink/src/presentation/widgets/web_page_view.dart';
import 'package:irllink/src/presentation/widgets/split_view_custom.dart';

class HomeView extends GetView<HomeViewController> {
  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height;
    final double width = MediaQuery.of(context).size.width;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => {
              FocusScope.of(context).unfocus(),
            },
            child: Container(
              constraints: BoxConstraints.expand(),
              decoration: BoxDecoration(
                color: Color(0xFF121212),
              ),
              child: SafeArea(
                child: SplitViewCustom(
                  controller: controller.splitViewController,
                  gripColor: Color(0xFF121212),
                  gripColorActive: Color(0xFF121212),
                  gripSize: 18,
                  viewMode: SplitViewMode.Vertical,
                  indicator: SplitIndicator(
                    viewMode: SplitViewMode.Vertical,
                    color: Color(0xFFFFFFFF),
                  ),
                  activeIndicator: SplitIndicator(
                    color: Color(0xFFFFFFFF),
                    viewMode: SplitViewMode.Vertical,
                    isActive: true,
                  ),
                  children: [
                    _tabBarCustomWindows(height, width),
                    ChatView(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0.0,
            left: 0.0,
            right: 0.0,
            child: _bottomNavBar(height, width, context),
          ),
        ],
      ),
    );
  }

  Widget _bottomNavBar(double height, double width, BuildContext context) {
    return Obx(
      () => Container(
        height: height * 0.06,
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.only(left: 10),
              width: width * 0.7,
              child: Stack(
                alignment: AlignmentDirectional.center,
                children: [
                  Container(
                    child: SvgPicture.asset(
                      './lib/assets/chatinput.svg',
                      semanticsLabel: 'chat input',
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.only(left: 5, right: 5),
                    child: Row(
                      children: [
                        Image(
                          image: AssetImage("lib/assets/twitchSmileEmoji.png"),
                          width: 30,
                        ),
                        Expanded(
                          child: TextField(
                            controller: controller.chatInputController,
                            onSubmitted: (String value) {
                              controller.sendChatMessage(value);
                              controller.chatInputController.text = '';
                              FocusScope.of(context).unfocus();
                            },
                            style: TextStyle(color: Colors.white),
                            maxLines: 1,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintStyle:
                                  TextStyle(color: Colors.white, fontSize: 16),
                              hintText: 'Send a message',
                              isDense: true,
                              contentPadding: EdgeInsets.only(left: 5),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            controller.sendChatMessage(
                                controller.chatInputController.text);
                            controller.chatInputController.text = '';
                            FocusScope.of(context).unfocus();
                          },
                          child: SvgPicture.asset(
                            './lib/assets/sendArrow.svg',
                            semanticsLabel: 'send message',
                            width: 21,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: width * 0.15,
              child: InkWell(
                onTap: () {
                  controller.sound.value = !controller.sound.value;
                },
                child: Icon(
                  controller.sound.value ? Icons.volume_up : Icons.volume_off,
                  color:
                      controller.sound.value ? Colors.white : Color(0xFFd63031),
                  size: 22,
                ),
              ),
            ),
            Container(
              width: width * 0.15,
              child: InkWell(
                onTap: () {
                  Get.toNamed(Routes.SETTINGS);
                },
                child: Icon(
                  Icons.settings,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBarCustomWindows(double height, double width) {
    return SizedBox(
      height: height / 2,
      width: width,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(50.0),
          child: AppBar(
            backgroundColor: Color(0xFF121212),
            bottom: TabBar(
              controller: controller.tabController,
              isScrollable: true,
              labelColor: Colors.purple,
              unselectedLabelColor: Colors.white,
              indicatorColor: Colors.purple,
              labelPadding: EdgeInsets.symmetric(
                  horizontal:
                      width / (controller.tabElements.length > 2 ? 9 : 5)),
              tabs: List<Tab>.generate(
                controller.tabElements.length,
                (int index) => Tab(
                  child: Text(
                    controller.tabElements[index].title,
                  ),
                ),
              ),
            ),
          ),
        ),
        body: SizedBox(
          height: double.infinity,
          child: TabBarView(
            physics: NeverScrollableScrollPhysics(),
            controller: controller.tabController,
            children: List<Widget>.generate(
              controller.tabElements.length,
              (int index) => controller.tabElements[index] is WebPage
                  ? WebPageView(controller.tabElements[index].toWebPage().url)
                  : controller.tabElements[index].title == "Twitch"
                      ? TwitchTabView()
                      : controller.tabElements[index].title == "OBS"
                          ? ObsTabView()
                          : Container(),
            ),
          ),
        ),
      ),
    );
  }
}
