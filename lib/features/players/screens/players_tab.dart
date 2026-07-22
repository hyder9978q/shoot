import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/player_request.dart';
import '../../../core/services/player_requests_service.dart';
import '../../../core/services/request_responses_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pressable.dart';
import 'new_request_screen.dart';

/// تبويب "ناقصنا لاعب" — إعلانات اليوم + نشر إعلان جديد
class PlayersTab extends StatefulWidget {
  const PlayersTab({super.key});

  @override
  State<PlayersTab> createState() => _PlayersTabState();
}

class _PlayersTabState extends State<PlayersTab> {
  final _scrollController = ScrollController();
  List<PlayerRequest>? _requests;
  bool _error = false;

  /// جلب دفعة جاري — ما نطلب نفس الدفعة مرتين
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load();
    PlayerRequestsService.instance.revision.addListener(_load);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    PlayerRequestsService.instance.revision.removeListener(_load);
    _scrollController.dispose();
    super.dispose();
  }

  /// قربنا من نهاية القائمة؟ نجيب الدفعة الجاية
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 400) return;
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !PlayerRequestsService.instance.hasMore) return;
    _loadingMore = true;
    try {
      final more = await PlayerRequestsService.instance.moreRequests();
      if (!mounted || more.isEmpty) return;
      await RequestResponsesService.instance.loadMyResponses([
        for (final r in more) r.id,
      ]);
      if (!mounted) return;
      setState(() => _requests = [...?_requests, ...more]);
    } catch (_) {
      // فشل دفعة إضافية ما يكسر القائمة المعروضة
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _load() async {
    try {
      final requests = await PlayerRequestsService.instance.todayRequests();
      // استعلام وحد يجيب انضماماتي بكل الدفعة المعروضة (مو واحد لكل بطاقة)
      await RequestResponsesService.instance.loadMyResponses([
        for (final r in requests) r.id,
      ]);
      if (mounted) {
        setState(() {
          _requests = requests;
          _error = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _requests = [];
          _error = true;
        });
      }
    }
  }

  Future<void> _delete(PlayerRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.deleteRequestTitle),
        content: Text(
          AppStrings.deleteRequestConfirm,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.dark.withValues(alpha: 0.8),
            height: 1.7,
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.keepRequest),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.yesDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await PlayerRequestsService.instance.deleteRequest(request);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.requestDeleted)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.requestPostError)),
      );
    }
  }

  void _openNewRequest() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NewRequestScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final requests = _requests;
    final myId = PlayerRequestsService.instance.currentUserId;

    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رأس أبيض: العنوان + زر النشر (نفس رأس حجوزاتي)
            Container(
              width: double.infinity,
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.playersTitle,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.dark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppStrings.playersSubtitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Pressable(
                    child: ElevatedButton.icon(
                      onPressed: _openNewRequest,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        AppStrings.postRequest,
                        style: TextStyle(fontSize: 13.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: requests == null
                    ? ListView.separated(
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                        itemCount: 3,
                        separatorBuilder: (_, _) => const SizedBox(height: 16),
                        itemBuilder: (_, _) => const _RequestSkeleton(),
                      )
                    : requests.isEmpty
                    ? _EmptyState(error: _error, onPost: _openNewRequest)
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                        // عنصر إضافي بالنهاية = هيكل تحميل الدفعة الجاية
                        itemCount:
                            requests.length +
                            (PlayerRequestsService.instance.hasMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 16),
                        itemBuilder: (_, i) => i >= requests.length
                            ? const _RequestSkeleton()
                            : _RequestCard(
                                request: requests[i],
                                isMine: requests[i].userId == myId,
                                onDelete: () => _delete(requests[i]),
                              ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة إعلان — شريط علوي + تفاصيل + أزرار تواصل بحد رفيع
class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.isMine,
    required this.onDelete,
  });

  final PlayerRequest request;
  final bool isMine;
  final VoidCallback onDelete;

  Future<void> _whatsapp() async {
    final phone = request.phone.replaceAll('+', '');
    final url = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(AppStrings.whatsappMessage)}',
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _call() async {
    await launchUrl(Uri.parse('tel:${request.phone}'));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          // شريط الهوية: أصفر لإعلاني، أخضر لإعلانات الباقين
          Container(
            height: 6,
            color: isMine ? AppColors.accent : AppColors.primary,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        request.sport.icon,
                        color: AppColors.primaryDark,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.dark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            request.sport.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isMine)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          AppStrings.myRequestBadge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accentInk,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                // المكان والوقت — سطر معلومات واحد
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        request.place,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: AppColors.grey,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${AppStrings.todayLabel} ',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: AppColors.grey,
                      ),
                    ),
                    Text(
                      request.timeLabel,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: AppColors.dark,
                      ),
                    ),
                  ],
                ),
                if (request.note.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      request.note,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        color: AppColors.grey,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // أزرار البطاقة — إعلاني: حذف؛ إعلان غيري: واتساب + اتصال
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.hairline)),
            ),
            child: isMine
                ? Pressable(
                    onTap: onDelete,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            AppStrings.deleteRequestTitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      _JoinButton(request: request),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Pressable(
                                child: ElevatedButton.icon(
                                  onPressed: _whatsapp,
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(0, 44),
                                  ),
                                  icon: const Icon(
                                    Icons.chat_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    AppStrings.whatsappContact,
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: Pressable(
                                child: OutlinedButton.icon(
                                  onPressed: _call,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primaryDark,
                                    side: BorderSide(color: AppColors.border),
                                    minimumSize: const Size(0, 44),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    textStyle: AppTheme.cairo(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.call_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(AppStrings.callContact),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// زر "أني أجي" — انضمام حقيقي يُحسب لشارة "منقذ" بملف اللاعب.
/// الحالة نفسها (انضممت أو لا) تُقرأ مباشرة من الخدمة — دليل حقيقي
/// موجود فعلاً بـ Firestore، ما نخزّنه محلياً بالواجهة.
class _JoinButton extends StatefulWidget {
  const _JoinButton({required this.request});

  final PlayerRequest request;

  @override
  State<_JoinButton> createState() => _JoinButtonState();
}

class _JoinButtonState extends State<_JoinButton> {
  bool _loading = false;

  Future<void> _toggle() async {
    if (_loading) return;
    setState(() => _loading = true);
    final wasJoined = RequestResponsesService.instance.hasResponded(
      widget.request.id,
    );
    try {
      if (wasJoined) {
        await RequestResponsesService.instance.withdraw(widget.request);
      } else {
        await RequestResponsesService.instance.respond(widget.request);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasJoined
                  ? AppStrings.withdrawnMsg
                  : AppStrings.joinRequestSuccess,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.joinRequestError)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final joined = RequestResponsesService.instance.hasResponded(
      widget.request.id,
    );
    return Pressable(
      onTap: _loading ? null : _toggle,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: joined ? AppColors.primaryTint : AppColors.primary,
          borderRadius: BorderRadius.circular(14),
          border: joined
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.4))
              : null,
        ),
        child: _loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: joined ? AppColors.primary : AppColors.white,
                ),
              )
            : Text(
                joined ? AppStrings.joinedRequest : AppStrings.joinRequest,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: joined ? AppColors.primaryDark : AppColors.white,
                ),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.error, required this.onPost});

  final bool error;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              Icons.group_add_outlined,
              size: 48,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          error ? AppStrings.requestsLoadError : AppStrings.noRequestsTitle,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (!error) ...[
          const SizedBox(height: 8),
          Text(
            AppStrings.noRequestsMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.grey,
              fontWeight: FontWeight.w600,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Pressable(
              child: ElevatedButton.icon(
                onPressed: onPost,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 50),
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(AppStrings.postRequest),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// هيكل تحميل بطاقة إعلان
class _RequestSkeleton extends StatelessWidget {
  const _RequestSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double width, double height, [double radius = 8]) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.subtleFill,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              block(46, 46, 14),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  block(140, 15),
                  const SizedBox(height: 6),
                  block(80, 12),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          block(double.infinity, 13),
          const SizedBox(height: 16),
          block(double.infinity, 44, 16),
        ],
      ),
    );
  }
}
