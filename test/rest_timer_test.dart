import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracking/features/workout/presentation/rest_timer.dart';

void main() {
  // Controller menyimpan durasi terakhir lewat SharedPreferences.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('formatRest', () {
    test('di bawah satu menit ditulis dalam detik', () {
      expect(formatRest(45), '45d');
    });

    test('kelipatan menit tidak menyebut detik', () {
      expect(formatRest(120), '2m');
    });

    test('sisa detik ikut ditulis', () {
      expect(formatRest(90), '1m 30d');
    });
  });

  group('RestTimerController', () {
    test('mundur satu detik tiap detik', () {
      fakeAsync((async) {
        final controller = RestTimerController()..start(10);
        expect(controller.remaining, 10);
        expect(controller.running, isTrue);

        async.elapse(const Duration(seconds: 3));
        expect(controller.remaining, 7);

        controller.dispose();
      });
    });

    test('berhenti dan menandai selesai saat mencapai nol', () {
      fakeAsync((async) {
        final controller = RestTimerController()..start(3);

        async.elapse(const Duration(seconds: 3));
        expect(controller.remaining, 0);
        expect(controller.running, isFalse);
        expect(controller.finished, isTrue);
        expect(controller.visible, isTrue);

        controller.dispose();
      });
    });

    test('penanda selesai hilang sendiri setelah beberapa detik', () {
      fakeAsync((async) {
        final controller = RestTimerController()..start(2);

        async.elapse(const Duration(seconds: 2));
        expect(controller.visible, isTrue);

        async.elapse(const Duration(seconds: 10));
        expect(controller.visible, isFalse);

        controller.dispose();
      });
    });

    test('tidak terus mundur di bawah nol setelah selesai', () {
      fakeAsync((async) {
        final controller = RestTimerController()..start(2);

        async.elapse(const Duration(seconds: 30));
        expect(controller.remaining, 0);

        controller.dispose();
      });
    });

    test('adjust menambah sisa waktu dan ikut menaikkan total', () {
      fakeAsync((async) {
        final controller = RestTimerController()..start(60);

        async.elapse(const Duration(seconds: 5));
        expect(controller.remaining, 55);

        controller.adjust(15);
        expect(controller.remaining, 70);
        // Total ikut naik supaya bar progres tidak melompat mundur.
        expect(controller.total, 70);
        expect(controller.progress, 0);

        controller.dispose();
      });
    });

    test('adjust tidak bisa membuat sisa waktu nol atau negatif', () {
      fakeAsync((async) {
        final controller = RestTimerController()..start(20);

        controller.adjust(-60);
        expect(controller.remaining, 1);
        expect(controller.running, isTrue);

        controller.dispose();
      });
    });

    test('adjust diabaikan saat timer tidak berjalan', () {
      final controller = RestTimerController();
      controller.adjust(30);

      expect(controller.remaining, 0);
      expect(controller.running, isFalse);

      controller.dispose();
    });

    test('stop menyembunyikan bar dan menghentikan hitungan', () {
      fakeAsync((async) {
        final controller = RestTimerController()..start(60);

        async.elapse(const Duration(seconds: 2));
        controller.stop();

        expect(controller.visible, isFalse);
        final sisa = controller.remaining;
        async.elapse(const Duration(seconds: 5));
        expect(controller.remaining, sisa);

        controller.dispose();
      });
    });

    test('start ulang mengganti hitungan yang sedang berjalan', () {
      fakeAsync((async) {
        final controller = RestTimerController()..start(60);

        async.elapse(const Duration(seconds: 10));
        controller.start(30);
        expect(controller.remaining, 30);

        // Ticker lama harus sudah dibatalkan; kalau tidak, sisanya berkurang
        // dua kali lebih cepat.
        async.elapse(const Duration(seconds: 5));
        expect(controller.remaining, 25);

        controller.dispose();
      });
    });

    test('durasi tidak wajar dibatasi, bukan diterima apa adanya', () {
      fakeAsync((async) {
        final controller = RestTimerController()..start(999999);
        expect(controller.total, 60 * 30);

        controller.dispose();
      });
    });
  });

  group('loadLastDuration', () {
    test('memakai bawaan kalau belum pernah disimpan', () async {
      expect(await RestTimerController.loadLastDuration(), kDefaultRestSeconds);
    });

    test('membaca nilai yang tersimpan', () async {
      SharedPreferences.setMockInitialValues({'rest_timer_seconds': 120});
      expect(await RestTimerController.loadLastDuration(), 120);
    });

    test('nilai rusak dari penyimpanan ikut dibatasi', () async {
      SharedPreferences.setMockInitialValues({'rest_timer_seconds': -5});
      expect(await RestTimerController.loadLastDuration(), 1);
    });
  });
}
