# SDK iOS da Assinafy

*Português · [Read in English](README.en.md)*

Acesso nativo em Swift e Objective-C à [API Assinafy v1](https://api.assinafy.com.br/v1/docs) —
plataforma brasileira de assinatura eletrônica: documentos, signatários, assignments, campos, tags,
templates, workspaces, webhooks e autenticação.

O SDK cobre todas as operações do documento OpenAPI v1 publicado. As requisições são
`async`/`await` primeiro, com wrappers de completion handler para Objective-C. As respostas decodificam
em modelos tipados, e as falhas aparecem como quatro tipos distintos de erro Swift que fazem bridge
limpo para `NSError`.

> **Referência completa em inglês.** Este documento cobre requisitos, instalação, configuração do
> cliente e como as credenciais são enviadas. O guia completo do ciclo de vida está em
> **[README.en.md](README.en.md)**, e a referência em
> [docs/API_REFERENCE.md](docs/API_REFERENCE.md).

## Requisitos

| | |
| --- | --- |
| iOS | 16.0+ |
| macOS | 12.0+ |
| Swift | 6.3+ (modo de linguagem 6) |
| Xcode | 26.6+ |

Swift e Xcode não têm canal de release LTS. Estas são as versões estáveis atuais da toolchain contra
as quais este pacote é compilado e testado.

## Instalação

Adicione o pacote e o produto ao `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/assinafy/mobile-ios-sdk.git",
        from: "1.4.0"
    ),
],
targets: [
    .target(
        name: "SeuApp",
        dependencies: [
            .product(name: "Assinafy", package: "mobile-ios-sdk"),
        ]
    ),
]
```

No Xcode, escolha **File → Add Package Dependencies…** e informe a URL do repositório.

## Início rápido

Enviar um PDF para um signatário:

```swift
import Assinafy

let client = AssinafyClient(token: bearerToken, defaultAccountId: accountId)

let enviado = try await client.documents.upload(pdfData)
let documento = try await client.documents.waitUntilReady(documentId: enviado.id)

let signatario = try await client.signers.create(
    CreateSignerPayload(fullName: "Ana Souza", email: "ana@exemplo.invalid")
)

let assignment = try await client.assignments.create(
    documentId: documento.id,
    payload: .withSignerIds([signatario.id], method: .virtual, message: "Por favor, revise e assine.")
)
```

## Configurando o cliente

Crie **um** cliente e mantenha uma referência forte a ele. `AssinafyClient` é thread-safe e seus
objetos de recurso são visões sem estado sobre um transporte compartilhado.

```swift
import Assinafy

let configuration = AssinafyClientConfiguration(
    token: bearerToken,        // ou apiKey:, nunca os dois
    baseURL: AssinafyClientConfiguration.productionBaseURL,
    defaultAccountId: accountId,
    timeout: 30,
    logger: NoopLogger()
)
try configuration.validate()
let client = AssinafyClient(configuration: configuration)
```

> **Escolha a credencial que combina com onde o código roda.** Tokens bearer pertencem a apps móveis
> distribuídos. Uma chave de API permanente concede acesso permanente a todo o workspace e pertence a
> um back-end confiável — **nunca** a um bundle de app, de onde pode ser extraída.

`defaultAccountId` é aplicado a toda chamada com escopo de conta. Qualquer método que receba um
argumento `accountId` o sobrescreve naquela chamada.

A configuração **falha fechada**. `validate()` rejeita credenciais conflitantes ou malformadas,
timeout não positivo ou não finito, identificador inseguro, e qualquer URL base que não seja uma URL
HTTPS absoluta livre de informação de usuário, query e fragmento. As mesmas checagens rodam em toda
requisição, então um cliente construído sem chamar `validate()` lança `ValidationError` antes de
fazer I/O de rede, em vez de enviar uma requisição malformada.

Algumas operações não precisam de credencial alguma. Deixe as duas de fora para login, redefinição de
senha e as rotas públicas de documento:

```swift
let publicClient = AssinafyClient(configuration: AssinafyClientConfiguration())

let session = try await publicClient.auth.login(
    LoginPayload(email: email, password: password)
)
```

## Como as credenciais são enviadas

A API v1 coloca cada operação em uma de três classes de autenticação, e o SDK **impõe** essa
separação em vez de anexar credenciais indiscriminadamente.

| Classe | Como a API autentica | O que o SDK envia |
| --- | --- | --- |
| **Conta** | `Authorization: Bearer {token}` ou `X-Api-Key: {chave}` | O header da credencial configurada |
| **Signatário** | O parâmetro de query exato `signer-access-code={código}` | Apenas o parâmetro de query |
| **Público** | Nada | Nada |

Um cliente configurado com token bearer ou chave de API **não** o transmite a uma operação de
Signatário ou Pública. Isso significa que um mesmo cliente pode servir os dois lados de um fluxo: a
mesma instância pode gerenciar documentos com uma credencial de conta e conduzir um signatário por
`assignments.sign(…)` sem que aquela credencial saia das rotas que a aceitam.

Códigos de acesso são segredos. Trate um `signerAccessCode` exatamente como trataria uma senha: nunca
registre em log, nunca persista além da sessão de assinatura, e nunca o coloque em uma URL que você
compartilhe.

## Métodos de verificação do signatário

Definidos por signatário ao criar o assignment. O método de verificação e o de notificação são
**acoplados**: envie um, os dois ou nenhum — o lado que faltar é inferido. Sem nenhum dos dois, ambos
assumem `Email`.

| Método | Como funciona | Custo por signatário |
| --- | --- | --- |
| `Email` *(padrão)* | Código de uso único (OTP) por e-mail, exigido antes de assinar | Gratuito |
| `Whatsapp` | Código de uso único (OTP) por WhatsApp | Verificação gratuita; notificação 0,45 crédito, só em planos pagos |
| `DigitalCertificate` | O signatário assina com o **próprio certificado ICP-Brasil (A1/A3)**, pela extensão de navegador Web PKI, gerando uma assinatura **PAdES qualificada** | 2 créditos |

Combinações permitidas: `Email` → notifica por `Email`; `Whatsapp` → notifica por `Whatsapp`;
`DigitalCertificate` → notifica por `Email` **ou** `Whatsapp`. Apenas um método de notificação por
signatário.

O certificado digital exige o recurso na conta (planos Standard e Pro), CPF ou CNPJ em
`government_id`, e que o signatário esteja **sozinho no seu passo**. Como a assinatura por
certificado acontece por um handshake de dois passos com a extensão de navegador Web PKI
(`/v1/signers/certificate/start` + `/complete`, rotas **somente de produção**), ela não é concluída
pelo fluxo de assinatura nativo deste SDK — encaminhe o signatário à página web de assinatura.

## Trilha de atividades e artefatos

As atividades de um documento devolvem todos os eventos registrados, cada um com um snapshot do
`payload` do evento e a `origin` da requisição (`ip`, `user-agent`).

| Artefato | Conteúdo |
| --- | --- |
| `original` | O PDF enviado, como recebido |
| `certificated` | O documento assinado, com a certificação da plataforma |
| `certificate-page` | Apenas a página de certificação |
| `pades` | Assinaturas ICP-Brasil dos signatários + caixa de certificação — só existe em documentos que tiveram signatários por certificado digital |
| `bundle` | Zip com `original`, `certificated` e `certificate-page`, mais o `pades` quando houver |

A verificação pública confere um documento assinado pelo hash da assinatura, sem autenticação.

## Ambientes

| | |
| --- | --- |
| Produção | `AssinafyClientConfiguration.productionBaseURL` |
| Sandbox | `https://sandbox.assinafy.com.br/v1` |

## Documentação

- **[README.en.md](README.en.md)** — guia completo do ciclo de vida, em inglês
- [docs/API_REFERENCE.md](docs/API_REFERENCE.md) — referência da API
- [Documentação da API](https://api.assinafy.com.br/v1/docs)

## Licença

Distribuído sob a licença [MIT](LICENSE).
