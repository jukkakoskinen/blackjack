package main

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

BLACKJACK :: 21
DEALER_LIMIT :: 17

CARD_WIDTH :: 48
CARD_HEIGHT :: 64
CARD_SPEED :: 1000

SCREEN_WIDTH :: 320
SCREEN_HEIGHT :: 240
SCREEN_CENTER :: rl.Vector2{SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2}

Suit :: enum {
	Heart,
	Diamond,
	Club,
	Spade,
}

Rank :: enum {
	Ace,
	Two,
	Three,
	Four,
	Five,
	Six,
	Seven,
	Eight,
	Nine,
	Ten,
	Jack,
	Queen,
	King,
}

Card :: struct {
	suit: Suit,
	rank: Rank,
}

Table_Card :: struct {
	card:     Card,
	face_up:  bool,
	position: rl.Vector2,
}

Hand :: enum {
	Player,
	Dealer,
}

Game_Play :: struct {
	turn: Hand,
}

Game_Over :: struct {
	winner: Maybe(Hand),
}

Game_State :: union {
	Game_Play,
	Game_Over,
}

Game :: struct {
	cards_texture: rl.Texture,
	state:         Game_State,
	deck:          [dynamic]Card,
	player:        [dynamic]Table_Card,
	dealer:        [dynamic]Table_Card,
}

Text_Align :: enum {
	Start,
	Center,
	End,
}

create_game :: proc() -> Game {
	game := Game {
		cards_texture = rl.LoadTexture("./res/cards.png"),
		deck          = make([dynamic]Card),
		player        = make([dynamic]Table_Card),
		dealer        = make([dynamic]Table_Card),
	}
	init_game(&game)
	return game
}

init_game :: proc(game: ^Game) {
	clear(&game.deck)
	for suit in Suit {
		for rank in Rank {
			append(&game.deck, Card{suit = suit, rank = rank})
		}
	}
	rand.shuffle(game.deck[:])
	clear(&game.player)
	for i in 0 ..< 2 {
		deal_card(game, .Player)
	}
	clear(&game.dealer)
	for i in 0 ..< 2 {
		deal_card(game, .Dealer, i > 0)
	}
	game.state = Game_Play {
		turn = .Player,
	}
}

destroy_game :: proc(game: ^Game) {
	rl.UnloadTexture(game.cards_texture)
	delete(game.deck)
	delete(game.player)
	delete(game.dealer)
}

card_texture_rect :: proc(card: Card, face_up: bool) -> rl.Rectangle {
	return(
		face_up ? rl.Rectangle{f32(CARD_WIDTH * int(card.rank)), f32(CARD_HEIGHT * int(card.suit)), CARD_WIDTH, CARD_HEIGHT} : rl.Rectangle{CARD_WIDTH * 2, CARD_HEIGHT * 4, CARD_WIDTH, CARD_HEIGHT} \
	)
}

deal_card :: proc(game: ^Game, hand: Hand, face_up: bool = true) {
	tc := Table_Card {
		card    = pop(&game.deck),
		face_up = face_up,
	}
	switch hand {
	case .Player:
		tc.position = {SCREEN_CENTER.x - CARD_WIDTH / 2, SCREEN_HEIGHT}
		append(&game.player, tc)
	case .Dealer:
		tc.position = {SCREEN_CENTER.x - CARD_WIDTH / 2, -CARD_HEIGHT}
		append(&game.dealer, tc)
	}
}

rank_value :: proc(rank: Rank) -> int {
	#partial switch rank {
	case .Jack, .Queen, .King:
		return 10
	case .Ace:
		return 11
	case:
		return int(rank) + 1
	}
}

hand_value :: proc(hand: []Table_Card) -> int {
	total := 0
	for tc in hand {
		if tc.face_up {
			total += rank_value(tc.card.rank)
		}
	}
	if total > 21 {
		for tc in hand {
			if tc.face_up && tc.card.rank == .Ace {
				total -= rank_value(Rank.Ace)
				total += 1
			}
		}
	}
	return total
}

update_hand :: proc(hand: []Table_Card, origin: rl.Vector2, delta: f32) {
	spacing := CARD_WIDTH / 3
	width := (len(hand) - 1) * spacing + CARD_WIDTH
	start_x := origin.x - f32(width / 2)
	for &tc, i in hand {
		target_position := rl.Vector2{start_x + f32(i * spacing), origin.y}
		tc.position = rl.Vector2MoveTowards(tc.position, target_position, CARD_SPEED * delta)
	}
}

update_game :: proc(game: ^Game, delta: f32) {
	update_hand(game.player[:], SCREEN_CENTER + {0, 32}, delta)
	update_hand(game.dealer[:], SCREEN_CENTER - {0, CARD_HEIGHT + 32}, delta)
	switch &s in game.state {
	case Game_Play:
		switch s.turn {
		case .Player:
			if hand_value(game.player[:]) > BLACKJACK {
				game.dealer[0].face_up = true
				game.state = Game_Over {
					winner = .Dealer,
				}
				return
			}
			if rl.IsKeyPressed(rl.KeyboardKey.S) {
				game.dealer[0].face_up = true
				s.turn = .Dealer
			} else if rl.IsKeyPressed(rl.KeyboardKey.H) {
				deal_card(game, .Player)
			}
		case .Dealer:
			dealer_hand_value := hand_value(game.dealer[:])
			player_hand_value := hand_value(game.player[:])
			if dealer_hand_value < DEALER_LIMIT {
				deal_card(game, .Dealer)
				return
			}
			if dealer_hand_value > BLACKJACK {
				game.state = Game_Over {
					winner = .Player,
				}
			} else if dealer_hand_value > player_hand_value {
				game.state = Game_Over {
					winner = .Dealer,
				}
			} else if dealer_hand_value < player_hand_value {
				game.state = Game_Over {
					winner = .Player,
				}
			} else {
				game.state = Game_Over {
					winner = nil,
				}
			}
		}
	case Game_Over:
		if rl.IsKeyPressed(rl.KeyboardKey.R) {
			init_game(game)
		}
	}
}

draw_text :: proc(
	text: cstring,
	origin: rl.Vector2,
	color: rl.Color,
	h_align: Text_Align = .Start,
	v_align: Text_Align = .Start,
) {
	size := rl.MeasureTextEx(rl.GetFontDefault(), text, 12, 1)
	position: rl.Vector2
	switch h_align {
	case .Start:
		position.x = origin.x
	case .Center:
		position.x = origin.x - size.x / 2
	case .End:
		position.x = origin.x - size.x
	}
	switch v_align {
	case .Start:
		position.y = origin.y
	case .Center:
		position.y = origin.y - size.y / 2
	case .End:
		position.y = origin.x - size.y
	}
	rl.DrawTextEx(rl.GetFontDefault(), text, position, 12, 1, rl.WHITE)
}

draw_hand :: proc(hand: []Table_Card, cards_texture: rl.Texture) {
	for tc, i in hand {
		rect := card_texture_rect(tc.card, tc.face_up)
		rl.DrawTextureRec(cards_texture, rect, tc.position, rl.WHITE)
	}
}

draw_outcome :: proc(text: cstring, text_bg: rl.Color) {
	overlay_color := rl.Fade(rl.BLACK, 0.8)
	rl.DrawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, overlay_color)

	text_bg_pos := rl.Vector2{SCREEN_CENTER.x - 40, SCREEN_CENTER.y - 8}
	rl.DrawRectangleRounded({text_bg_pos.x, text_bg_pos.y, 80, 16}, 1, 0, text_bg)
	draw_text(text, SCREEN_CENTER, rl.WHITE, .Center, .Center)

	reset_text_pos := SCREEN_CENTER + rl.Vector2{0, 16}
	draw_text("Press R to play again", reset_text_pos, rl.WHITE, .Center)
}

draw_game :: proc(game: Game) {
	rl.DrawLineEx({0, SCREEN_CENTER.y}, {SCREEN_WIDTH, SCREEN_CENTER.y}, 1, rl.Fade(rl.WHITE, 0.6))
	draw_text("H - Hit", {8, 16}, rl.WHITE, .Start, .Center)
	draw_text("S - Stand", {8, 32}, rl.WHITE, .Start, .Center)

	dealer_value := rl.TextFormat("%d", hand_value(game.dealer[:]))
	draw_text(dealer_value, SCREEN_CENTER - {0, 16}, rl.WHITE, .Center, .Center)
	draw_hand(game.dealer[:], game.cards_texture)

	player_value := rl.TextFormat("%d", hand_value(game.player[:]))
	draw_text(player_value, SCREEN_CENTER + {0, 16}, rl.WHITE, .Center, .Center)
	draw_hand(game.player[:], game.cards_texture)

	if s, ok := game.state.(Game_Over); ok {
		switch s.winner {
		case .Player:
			draw_outcome("You win!", rl.DARKGREEN)
		case .Dealer:
			draw_outcome("You lose!", rl.RED)
		case nil:
			draw_outcome("It's a tie!", rl.BLUE)
		}
	}
}

main :: proc() {
	rl.InitWindow(SCREEN_WIDTH * 2, SCREEN_HEIGHT * 2, "Blackjack")
	rl.SetMouseScale(0.5, 0.5)
	rl.SetTargetFPS(144)
	defer rl.CloseWindow()

	rt := rl.LoadRenderTexture(SCREEN_WIDTH, SCREEN_HEIGHT)
	rl.SetTextureFilter(rt.texture, rl.TextureFilter.POINT)
	defer rl.UnloadRenderTexture(rt)

	game := create_game()
	defer destroy_game(&game)

	for !rl.WindowShouldClose() {
		delta: f32 = rl.GetFrameTime()
		update_game(&game, delta)

		rl.BeginTextureMode(rt)
		rl.ClearBackground(rl.BLANK)
		draw_game(game)
		rl.EndTextureMode()

		rl.BeginDrawing()
		rl.ClearBackground(rl.DARKGREEN)
		rl.DrawTexturePro(
			rt.texture,
			{0, 0, f32(rt.texture.width), f32(-rt.texture.height)},
			{0, 0, SCREEN_WIDTH * 2, SCREEN_HEIGHT * 2},
			{0, 0},
			0,
			rl.WHITE,
		)
		rl.EndDrawing()
	}
}
