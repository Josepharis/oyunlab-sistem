import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/customer_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

class CountdownCard extends StatefulWidget {
  final Customer customer;
  final VoidCallback? onTap;
  final int siblingCount; // Kardeş sayısı

  const CountdownCard({
    super.key,
    required this.customer,
    this.onTap,
    this.siblingCount = 1,
  });

  @override
  State<CountdownCard> createState() => _CountdownCardState();
}

class _CountdownCardState extends State<CountdownCard>
    with SingleTickerProviderStateMixin {
  late Duration _remainingTime;
  late Timer _timer;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _remainingTime = widget.customer.remainingTime;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingTime = widget.customer.remainingTime;
      });
    });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _timer.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    final progress = _remainingTime.inMinutes / widget.customer.durationMinutes;

    if (progress > 0.5) {
      return Colors.green.shade600;
    } else if (progress > 0.25) {
      return Colors.amber.shade700;
    } else {
      return Colors.red.shade600;
    }
  }

  String _formatTime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return '${hours > 0 ? '$hours:' : ''}${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime time) {
    final now = DateTime.now();
    final isToday =
        time.day == now.day && time.month == now.month && time.year == now.year;

    if (isToday) {
      return DateFormat('HH:mm').format(time);
    } else {
      return DateFormat('dd.MM HH:mm').format(time);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor();
    final timeStr = _formatTime(_remainingTime);
    final progress =
        _remainingTime.inSeconds / (widget.customer.durationMinutes * 60);

    return FadeTransition(
      opacity: _animation,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10.0),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.2),
                  offset: const Offset(0, 2),
                  blurRadius: 6.0,
                ),
              ],
              border: Border.all(
                color: statusColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Progress bar (sol kenar)
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),

                // Avatar ve isim
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        // Avatar
                        Stack(
                          children: [
                            Hero(
                              tag: 'avatar-${widget.customer.id}',
                              child: Container(
                                width: 45,
                                height: 45,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      statusColor.withOpacity(0.9),
                                      statusColor.withOpacity(0.7),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    widget.customer.childName
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Duraklatma göstergesi
                            if (widget.customer.isPaused)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.pause_rounded,
                                    color: Colors.blue.shade600,
                                    size: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(width: 10),

                        // İsim ve bilgiler
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.customer.childName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '#${widget.customer.ticketNumber}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                widget.customer.parentName,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 2),
                              Row(
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.phone_outlined,
                                        size: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      SizedBox(width: 2),
                                      Text(
                                        widget.customer.phoneNumber,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Giriş/Çıkış bilgileri (orta kısım)
                Container(width: 1, height: 50, color: Colors.grey.shade200),
                SizedBox(width: 8),

                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTimeInfoRow(
                      Icons.login_outlined,
                      _formatDateTime(widget.customer.entryTime),
                      Colors.blue.shade700,
                    ),
                    SizedBox(height: 6),
                    _buildTimeInfoRow(
                      Icons.logout_outlined,
                      _formatDateTime(widget.customer.exitTime),
                      Colors.green.shade700,
                    ),
                  ],
                ),
                SizedBox(width: 8),

                // Geri sayım (en sağ)
                Container(width: 1, height: 50, color: Colors.grey.shade200),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          statusColor.withOpacity(0.15),
                          statusColor.withOpacity(0.05),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Süre gösterimi - Stack'i kaldırıyorum
                        widget.customer.isPaused
                            ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.pause_circle_filled,
                                  color: Colors.blue.shade600,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'DURAKLATILDI',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade600,
                                  ),
                                ),
                              ],
                            )
                            : Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),

                        // Kalan ve kişi sayısı yan yana
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.customer.isPaused ? timeStr : 'kalan',
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    widget.customer.isPaused
                                        ? Colors.blue.shade600
                                        : statusColor.withOpacity(0.8),
                              ),
                            ),

                            // Kişi sayısı yan tarafa - çok daha büyük ve belirgin
                            if (widget.siblingCount > 1) ...[
                              SizedBox(width: 10),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 2,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.people,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      "${widget.siblingCount} kişi",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeInfoRow(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
