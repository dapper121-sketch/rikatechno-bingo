# RikaTechno Bingo V5.1 — Recuperação de cartelas

## Instalação
1. Se o SQL da V5 ainda NÃO foi executado, execute primeiro `upgrade_v5.sql` no Supabase. Caso a V5 já esteja instalada, não precisa repetir.
2. Execute `upgrade_v5_1.sql` no SQL Editor do **mesmo** projeto Supabase. Não apaga rodadas nem históricos.
3. No GitHub `dapper121-sketch/rikatechno-bingo`, substitua **somente** `index.html` pelo arquivo deste pacote. Os demais arquivos já devem estar publicados; estão incluídos apenas como cópia. O Render deverá atualizar se o deploy automático estiver ativo.
4. Faça login de Organizador. Em Histórico de cartelas finalizadas, abra uma entrada, use **Visualizar cartela fechada** para conferir os números, ou **Reabrir e continuar** para restaurar uma cópia.

## Regras importantes
- O fechamento original nunca é modificado. Cada reabertura cria uma **nova rodada numerada** com uma cópia dos números anteriores, na mesma ordem. A rodada continua normalmente e pode ser fechada novamente, produzindo uma nova entrada de histórico ligada à origem.
- A operação é negada caso a rodada atual esteja aberta e já possua números sorteados. Nesse caso, feche-a primeiro com BINGO.
- Somente administradores autenticados podem reabrir e consultar o histórico; a reabertura fica gravada em `bingo_reopen_log` com origem, rodada de destino, usuário e horário.
- A atualização é feita no banco sob trava da rodada, impedindo duas reaberturas simultâneas.
- O histórico fechado anterior continua acessível, e os participantes enxergam automaticamente a cartela restaurada.
- Teste primeiro com uma rodada de ensaio. Não rode `upgrade_v5_1.sql` antes do `upgrade_v5.sql`.
- Não publique senhas ou a chave secreta do Supabase no GitHub. `config.js` contém apenas a chave pública.
