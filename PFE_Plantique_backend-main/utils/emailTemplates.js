exports.generateResetEmailTemplate = (code, name = "Utilisateur") => {
  return `
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Réinitialisation du mot de passe</title>
</head>
<body style="margin:0;padding:0;background-color:#f4f7f4;font-family:'Segoe UI',Arial,sans-serif;">

  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f7f4;padding:40px 0;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.08);">

          <!-- Header -->
          <tr>
            <td style="background:linear-gradient(135deg,#2d6a4f 0%,#52b788 100%);padding:36px 40px;text-align:center;">
              <p style="margin:0;font-size:28px;font-weight:700;color:#ffffff;letter-spacing:1px;">🌿 Plantique</p>
              <p style="margin:8px 0 0;font-size:14px;color:#d8f3dc;letter-spacing:0.5px;">Votre compagnon jardinage</p>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:40px 48px 32px;">
              <p style="margin:0 0 8px;font-size:22px;font-weight:600;color:#1b4332;">Bonjour ${name} 👋</p>
              <p style="margin:12px 0 0;font-size:15px;color:#555;line-height:1.7;">
                Nous avons reçu une demande de réinitialisation de votre mot de passe.<br/>
                Utilisez le code ci-dessous pour continuer. Il est valable <strong>15 minutes</strong>.
              </p>

              <!-- Code block -->
              <div style="margin:32px 0;text-align:center;">
                <div style="display:inline-block;background:#f0faf4;border:2px dashed #52b788;border-radius:12px;padding:24px 48px;">
                  <p style="margin:0 0 6px;font-size:12px;font-weight:600;color:#52b788;text-transform:uppercase;letter-spacing:2px;">Votre code</p>
                  <p style="margin:0;font-size:42px;font-weight:800;color:#1b4332;letter-spacing:12px;">${code}</p>
                </div>
              </div>

              <p style="margin:0;font-size:14px;color:#888;line-height:1.7;">
                Si vous n'avez pas demandé cette réinitialisation, ignorez simplement cet e-mail. Votre mot de passe restera inchangé.
              </p>
            </td>
          </tr>

          <!-- Divider -->
          <tr>
            <td style="padding:0 48px;">
              <hr style="border:none;border-top:1px solid #e8f5e9;margin:0;" />
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding:24px 48px 36px;text-align:center;">
              <p style="margin:0;font-size:13px;color:#aaa;line-height:1.6;">
                Cet e-mail a été envoyé automatiquement, merci de ne pas y répondre.<br/>
                &copy; ${new Date().getFullYear()} Plantique. Tous droits réservés.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>

</body>
</html>
  `;
};
