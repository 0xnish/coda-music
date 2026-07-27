import 'package:expressive_refresh/expressive_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:Coda/core/utils/service_locator.dart';
import 'package:Coda/screens/home/cubit/home_cubit.dart';
import 'package:Coda/core/widgets/section_item.dart';
import 'package:Coda/utils/internet_guard.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:scroll_animator/scroll_animator.dart';

import '../../utils/adaptive_widgets/adaptive_widgets.dart';


class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit(sl()),
      child: _HomePage(),
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  late AnimatedScrollController _scrollController;
  late AnimatedScrollController _horizontalScrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = AnimatedScrollController(
      animationFactory: const ChromiumEaseInOut(),
    );
    _horizontalScrollController = AnimatedScrollController(
      animationFactory: const ChromiumEaseInOut(),
    );
    _scrollController.addListener(_scrollListener);
    _checkFirstLaunch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeCubit>().fetch();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _checkFirstLaunch() async {
    final box = Hive.box('SETTINGS');
    final hasSeenSupport = box.get('has_seen_support_dialog', defaultValue: false);
    
    if (!hasSeenSupport) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSupportDialog();
      });
      await box.put('has_seen_support_dialog', true);
    }
  }

  void _showSupportDialog() {
    context.go('/support');
  }

  Future<void> _scrollListener() async {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      await context.read<HomeCubit>().fetchNext();
    }
  }


  Widget _horizontalChipsRow(List data) {
    var list = <Widget>[const SizedBox(width: 16)];
    for (var element in data) {
      list.add(
        AdaptiveInkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.go('/chip', extra: element),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10)),
            child: Text(element['title']),
          ),
        ),
      );
      list.add(const SizedBox(
        width: 8,
      ));
    }
    list.add(const SizedBox(
      width: 8,
    ));
    return SingleChildScrollView(
      controller: _horizontalScrollController,
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: list,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InternetGuard(
      onInternetRestored: context.read<HomeCubit>().fetch,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ExpressiveRefreshIndicator(
          onRefresh: context.read<HomeCubit>().refresh,
          child: BlocBuilder<HomeCubit, HomeState>(
            builder: (context, state) {
              return switch (state) {
                HomeLoading() => Center(
                    child: LoadingIndicatorM3E(),
                  ),
                HomeError() => Center(
                    child: Text(state.message ?? ''),
                  ),
                HomeSuccess() => ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    controller: _scrollController,
                    child: SafeArea(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _horizontalChipsRow(state.chips),
                        Column(
                          children: [
                            ...state.sections.map((section) {
                              return SectionItem(section: section);
                            }),
                            if (!state.loadingMore &&
                                state.continuation != null)
                              const SizedBox(height: 50),
                            if (state.loadingMore)
                              const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: ExpressiveLoadingIndicator()),
                          ],
                        ),
                      ],
                    ))),
                  ),
              };
            },
          ),
        ),
      ),
    );
  }
}

