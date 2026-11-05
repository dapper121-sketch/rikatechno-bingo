# RikaTechno Bingo V4 — GitHub Pages + Supabase

## 1. Banco e login
1. No Supabase, abra seu projeto (ou crie um novo) e **SQL Editor**.
2. Execute `supabase.sql` completo.
3. Em **Authentication > Users**, crie seu usuário de administrador (e-mail/senha). Verifique se o usuário foi criado.
4. Volte ao SQL Editor e execute o `insert into public.bingo_admins` comentado no final do SQL, trocando pelo seu e-mail exato.
5. Em **Project Settings > API** (ou **Connect**), copie a **Project URL** e a chave **anon/publishable**. NUNCA use `service_role` ou secret key no frontend.
6. Coloque esses dois valores em `config.js`.

## 2. GitHub
No repositório `dapper121-sketch/rikatechno-bingo`, substitua `index.html` e envie `config.js` e todos os arquivos `favicon*` e `logo-rikatechno.png`. NÃO envie `supabase.sql` se preferir manter simples. O site continua no GitHub Pages. Para testes, acesse `https://dapper121-sketch.github.io/rikatechno-bingo/`.

## 3. Domínio
Para `bingo.rikatechno.com.br` no seu painel de DNS, crie um registro **CNAME** host `bingo` apontando para `dapper121-sketch.github.io` (sem `https://` e sem caminho). No repositório, **Settings > Pages > Custom domain** digite `bingo.rikatechno.com.br`, salve e habilite **Enforce HTTPS** depois do certificado. O GitHub criará/atualizará o CNAME. Não coloque o domínio Supabase como destino do DNS, porque a interface está no GitHub Pages. NÃO configure o domínio antes de substituir `rikatechno.com.br` pelo domínio real.

## 4. Operação
Todos veem a mesma cartela e os mesmos números. Para sortear, toque **Organizador**, entre com o usuário autorizado e use os botões. O banco garante ausência de repetição inclusive com dois administradores. **Sorteio automático** roda somente enquanto o navegador do organizador estiver ativo; animação de 3 segundos é visual, sem travar o banco. Atualizações ao vivo via Realtime; checagem extra a cada 5 segundos.

## Segurança
As chaves públicas do Supabase no arquivo `config.js` são previstas para browser. O banco protege escrita por RLS e funções que verificam o usuário. Não torne o `bingo_admins` público e não use secret/service_role no navegador. Se usar o mesmo projeto Supabase de outros sistemas, confira políticas e permissões separadamente. É recomendável usar um projeto exclusivo para o Bingo.

## Observação
Arquivos preparados, mas ainda não publicados e ainda não conectados ao seu projeto Supabase: faltam URL, chave pública, cadastro admin e DNS real.

## Configuração específica do domínio RikaTechno
- Em GitHub Pages > Custom domain, informe `bingo.rikatechno.com.br` e salve **antes de apontar DNS**. Isso criará/atualizará o arquivo CNAME.
- No painel do provedor DNS de `rikatechno.com.br`, crie um CNAME com **Host** `bingo` e **Destino** `dapper121-sketch.github.io` (não inclua https nem /rikatechno-bingo). Se já houver um registro para `bingo`, edite em vez de duplicar.
- Depois que o certificado aparecer, habilite Enforce HTTPS. Propagação DNS e certificado podem não ser imediatos.
- Para sincronização, crie projeto Supabase `rikatechno-bingo`, execute `supabase.sql`, crie usuário admin em Authentication > Users e autorize seu email na tabela bingo_admins usando o SQL comentado. Preencha somente URL do projeto e chave **publishable/anon** em config.js.
- Os arquivos do site já estão prontos; **não publicar a configuração com valores fictícios como sistema funcional**.
- Publique o site apenas depois de concluir a configuração Supabase.

## Projeto Supabase definido
- Project URL: `https://iqljyiqaxyfbklsjzcdf.supabase.co` — já preenchida em `config.js`.
- Falta copiar a **publishable key (sb_publishable_...)** em `config.js`, substituindo `COLE_A_CHAVE_PUBLICA_ANON_OU_PUBLISHABLE`.
- Use **SQL Editor** para executar `supabase.sql` e depois criar/autorizar seu usuário administrador.
- Nunca enviar senha, chave secret ou service_role.

## Configuração atual (05/11/2026)
- URL pública do Supabase e publishable key já foram inseridas no `config.js`.
- Execute `supabase.sql` no SQL Editor do projeto antes de publicar o frontend.
- Crie o usuário em Authentication > Users, e autorize o e-mail no `bingo_admins` com o INSERT comentado no fim do SQL.
- Suba `index.html`, `config.js`, imagens e `CNAME` na raiz do repositório; não envie o SQL nem senhas.
- A publishable key é pública por definição; a segurança depende de RLS e das funções SQL.
