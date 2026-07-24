import "package:flutter/material.dart";
import "public_page_scaffold.dart";

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicPageScaffold(
      title: "Política de Privacidade",
      lastUpdated: "24/07/2026",
      children: [
        publicParagraph("A Mduck Agency respeita a privacidade de seus usuários."),
        publicParagraph(
          "Esta plataforma é utilizada para gerenciamento interno da agência, onboarding de streamers, materiais, acompanhamento de desempenho e comunicação entre colaboradores e streamers.",
        ),
        publicSectionHeading("Os dados coletados podem incluir:"),
        publicBullet("informações cadastrais;"),
        publicBullet("dados fornecidos durante autenticação com TikTok;"),
        publicBullet("informações de contato;"),
        publicBullet("registros de utilização da plataforma."),
        publicSectionHeading("Esses dados são utilizados exclusivamente para:"),
        publicBullet("autenticação;"),
        publicBullet("gerenciamento da agência;"),
        publicBullet("segurança da plataforma;"),
        publicBullet("melhoria dos serviços;"),
        publicBullet("cumprimento de obrigações legais."),
        const SizedBox(height: 10),
        publicParagraph("A Mduck Agency não comercializa informações pessoais."),
        publicParagraph("Os dados são armazenados em ambiente seguro e acessados apenas por pessoas autorizadas."),
        publicParagraph(
          "Caso o usuário deseje solicitar alteração ou remoção de seus dados, poderá entrar em contato pelos canais oficiais da Mduck Agency.",
        ),
      ],
    );
  }
}
