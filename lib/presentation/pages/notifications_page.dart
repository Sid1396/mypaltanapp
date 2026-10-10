import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../data/models/home_models.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/notifications_controller.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(NotificationsController());
    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text('Notifications', style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w800, fontSize: SizeConfig.sp(18), color: Colors.white)),
      ),
      body: Obx(() {
        if (c.isLoading.value && c.items.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (c.items.isEmpty) {
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: c.load,
            child: ListView(
              children: [
                SizedBox(height: SizeConfig.h(140)),
                Icon(Icons.notifications_none_rounded, size: SizeConfig.r(56), color: Colors.white.withAlpha(60)),
                SizedBox(height: SizeConfig.h(14)),
                Text(
                  c.errorMessage.value.isNotEmpty ? c.errorMessage.value : 'No notifications yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(17), color: Colors.white),
                ),
                SizedBox(height: SizeConfig.h(6)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(40)),
                  child: Text(
                    'Team invites, fixtures, match results and tournament updates will show up here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Gilroy', fontSize: SizeConfig.sp(13), color: Colors.white.withAlpha(130), height: 1.45),
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: c.load,
          child: ListView.separated(
            padding: EdgeInsets.all(SizeConfig.r(16)),
            itemCount: c.items.length,
            separatorBuilder: (_, __) => SizedBox(height: SizeConfig.h(10)),
            itemBuilder: (_, i) => _NotificationTile(n: c.items[i]),
          ),
        );
      }),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification n;
  const _NotificationTile({required this.n});

  String _ago(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  void _open() {
    final t = n.target;
    if (t == null) return;
    Get.toNamed(t.$1 == 'team' ? AppRoutes.team : AppRoutes.tournament, arguments: {'code': t.$2});
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _open,
      child: Container(
        padding: EdgeInsets.all(SizeConfig.r(14)),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(SizeConfig.r(14)),
          border: Border.all(color: n.isRead ? Colors.transparent : AppColors.primary.withAlpha(80)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.notifications_rounded, color: AppColors.primary, size: SizeConfig.r(20)),
            SizedBox(width: SizeConfig.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title, style: TextStyle(fontFamily: 'Gilroy', fontWeight: FontWeight.w700, fontSize: SizeConfig.sp(14), color: Colors.white)),
                  if (n.body != null)
                    Text(n.body!, style: TextStyle(fontFamily: 'Gilroy', fontSize: SizeConfig.sp(13), color: Colors.white.withAlpha(150), height: 1.4)),
                ],
              ),
            ),
            Text(_ago(n.createdAt), style: TextStyle(fontFamily: 'Gilroy', fontSize: SizeConfig.sp(11), color: Colors.white.withAlpha(110))),
          ],
        ),
      ),
    );
  }
}
