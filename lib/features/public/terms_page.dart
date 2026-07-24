import "package:flutter/material.dart";
import "public_page_scaffold.dart";

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicPageScaffold(
      title: "Termos de Uso",
      lastUpdated: "24/07/2026",
      children: [
        publicParagraph("Ao utilizar esta plataforma você concorda com estes Termos de Uso."),
        publicParagraph("A plataforma Mduck Agency é destinada ao gerenciamento de colaboradores e streamers autorizados."),
        publicParagraph("O acesso é permitido somente para usuários previamente autorizados."),
        publicSectionHeading("O usuário compromete-se a:"),
        publicBullet("utilizar a plataforma de forma ética;"),
        publicBullet("manter suas credenciais em sigilo;"),
        publicBullet("não compartilhar informações confidenciais;"),
        publicBullet("respeitar as políticas internas da agência."),
        const SizedBox(height: 10),
        publicParagraph(
          "A Mduck Agency poderá suspender ou remover acessos que violem estes termos ou apresentem riscos à segurança da plataforma.",
        ),
        publicParagraph("Os Termos poderão ser atualizados periodicamente."),
        publicParagraph("O uso contínuo da plataforma representa concordância com futuras alterações."),
      ],
    );
  }
}
