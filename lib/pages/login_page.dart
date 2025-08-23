import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  bool _busy = false;
  bool _obscure = true;

  Future<void> _run(Future<void> Function() job) async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await job();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İşlem başarılı')),
      );
      // Auth state Stream’i zaten HomePage’e yönlendirecek.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Gradient arka plan
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primary.withOpacity(0.18),
                  cs.secondary.withOpacity(0.18),
                  cs.tertiary.withOpacity(0.18),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Hafif dekoratif daireler
          Positioned(
            top: -80,
            left: -40,
            child: _blurCircle(180, cs.primary.withOpacity(0.25)),
          ),
          Positioned(
            bottom: -60,
            right: -30,
            child: _blurCircle(140, cs.secondary.withOpacity(0.25)),
          ),

          // İçerik
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: _glassCard(
                    context: context,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        // Logo / simge
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: cs.primary.withOpacity(0.12),
                          child: Icon(Icons.lock_outline_rounded, color: cs.primary, size: 36),
                        ),
                        const SizedBox(height: 16),

                        // Başlık
                        Text(
                          'DataVault',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Dosyalarını güvenle yükle, indir ve yönet.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Form
                        Form(
                          key: _form,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.username, AutofillHints.email],
                                decoration: const InputDecoration(
                                  labelText: 'E-posta',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: (v) {
                                  final text = (v ?? '').trim();
                                  if (text.isEmpty) return 'E-posta boş olamaz';
                                  final ok = RegExp(r'^\S+@\S+\.\S+$').hasMatch(text);
                                  if (!ok) return 'Geçerli bir e-posta girin';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _pass,
                                obscureText: _obscure,
                                autofillHints: const [AutofillHints.password],
                                decoration: InputDecoration(
                                  labelText: 'Şifre',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                                  ),
                                ),
                                validator: (v) {
                                  final text = (v ?? '').trim();
                                  if (text.isEmpty) return 'Şifre boş olamaz';
                                  if (text.length < 6) return 'En az 6 karakter olmalı';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Giriş Butonu
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  icon: _busy
                                      ? SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2, color: cs.onPrimary,
                                    ),
                                  )
                                      : const Icon(Icons.login_rounded),
                                  label: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Text(_busy ? 'Giriş yapılıyor...' : 'Giriş Yap'),
                                  ),
                                  onPressed: _busy
                                      ? null
                                      : () => _run(() => AuthService.signIn(
                                    email: _email.text,
                                    password: _pass.text,
                                  )),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Ayırıcı
                              Row(
                                children: [
                                  Expanded(child: Divider(color: cs.outlineVariant)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      'veya',
                                      style: TextStyle(color: cs.onSurfaceVariant),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: cs.outlineVariant)),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Kayıt butonu
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.person_add_alt_1_rounded),
                                  label: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Text('Hesap Oluştur'),
                                  ),
                                  onPressed: _busy
                                      ? null
                                      : () => _run(() => AuthService.register(
                                    email: _email.text,
                                    password: _pass.text,
                                  )),
                                ),
                              ),

                              const SizedBox(height: 6),
                              // Küçük güvenlik notu
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.verified_user_outlined, size: 16, color: cs.onSurfaceVariant),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Bilgilerin güvenle saklanır',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Cam efekti kart
  Widget _glassCard({required BuildContext context, required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: child,
    );
  }

  // Arka plana yumuşak blur daire
  Widget _blurCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 80,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }
}
