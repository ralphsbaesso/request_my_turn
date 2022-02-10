# RequestMyTurn

Gem feita para utilizar a imagem [my-turn](https://hub.docker.com/r/ralphbaesso/my-turn).
Projeto feito para enfileirar requisições que utilizam a mesma chave.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'request_my_turn'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install request_my_turn

## Usage

```ruby
service = RequestMyTurn.new('my_key')
service.perform do
  # sua lógica aqui
end
```

#### Objetivo
Limitar acesso ao determinado recurso.

Quando executa *service.perform*, 
o *service* requisita um **id** para aquela chave e bloqueia todas as outros requisições com a mesma chave. 

Quando termina a sua lógica, o *service* devolve o **id** liberando a fila com aquela chave.

### Opções

```ruby
service = RequestMyTurn.new(
  'my_key', # chave da sua requisição
  url: 'https://examples.com', # url do servidor MyTurn
  before: -> id { p id }, # callback executado antes da lógica. O parâmetro é o id da requisição
  after: -> time { p time }, # callback executado depois da lógica e da devolução do id. O parâmetro é o tempo quasto do processo.
  switch: -> service { p service }, # liga/desliga a requisição para o servidor. Pode ser um valor true/false ou um callback. 
  timeout: 60, # tempo máximo de espera para aguardar na fila.
  lock_seconds: 60, # tempo para bloquear a fila no servidor. Default 60 segundos.
  headers: {}, # headers para enviar na requisição do servidor
  ignore_timeout_error: false, # Se verdade, lança um Exception quando ocorrer Timeout. 
)

```