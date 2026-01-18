import '../domain/motor_invernadero.dart';
import '../dev/dev_seed.dart' as dev_seed;

class AppRepository {
  final MotorInvernadero motor;

  AppRepository(this.motor);

  void seed() {
    motor.reset();
    dev_seed.seed(motor);
  }
}

