class_name TicketData
extends Resource
## Pedido de um cliente invisível (design §4).

enum State { OPEN, SERVED }

@export var id: int = 0
@export var nickname: String = ""
@export var phrase: String = ""
@export var recipe: String = "food_burger"
## Ids de camada que o cliente não quer.
@export var without: Array[String] = []
@export var state: State = State.OPEN
