/// Configuração de API para o cliente Flutter.
///
/// Ajuste o host conforme o ambiente:
/// - Web/Linux/desktop local: http://localhost:3000/api
/// - Emulador Android: http://10.0.2.2:3000/api
/// - Device físico: use o IP da máquina na mesma rede, ex: http://192.168.0.10:3000/api
class ApiConfig {
  static const String baseUrl = 'http://localhost:3000/api';
}
