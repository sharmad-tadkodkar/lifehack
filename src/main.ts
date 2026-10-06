import './style.css';
import { Game } from './engine/Game';
import { scenarios } from './scenarios';

const game = new Game(document.querySelector<HTMLElement>('#app')!);
game.showTitle(scenarios[0]);
