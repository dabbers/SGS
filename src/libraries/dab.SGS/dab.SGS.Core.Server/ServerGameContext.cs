using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using dab.SGS.Core;
using dab.SGS.Core.Cards.Playing;
using dab.SGS.Core.Controllers;

namespace dab.SGS.Core.Server
{
    public class ServerGameContext : GameContext
    {
        public ServerGameContext(Deck deck) : base(deck)
        {
        }
        public void AddPlayer(string display, Cards.Heroes.HeroCard hero)
        {
            this.AddPlayer(display, hero, Core.Roles.Random);
        }

        public Controller SetupGame(bool dealCards = true)
        {
            if (this.Players.Count() < 3) throw new Exceptions.InvalidScenarioException("Not enough players");

            this.dealCardsToPlayers();
            //this.CurrentPlayStage.Source = new TargetPlayer(this.Players.First().Left);

            var roles = Player.GetRoles(this.Players.Count());
            var computedRoles = this.Players.Select(p => ((ServerPlayer)p).Role).ToArray();

            Array.Sort(computedRoles);
            Array.Sort(roles);

            var rolesList = new List<Roles>(roles);

            for (var i = 0; i < computedRoles.Length; i++)
            {
                if (computedRoles[i] != Core.Roles.Random && computedRoles[i] != roles[i])
                {
                    throw new Exceptions.InvalidScenarioException("Invalid roles assigned!");
                }
            }

            if (computedRoles.Contains(Core.Roles.Random))
            {
                var newRoles = this.Players.Where(p =>
                {
                    if (rolesList.Contains(((ServerPlayer)p).Role))
                    {
                        rolesList.Remove(((ServerPlayer)p).Role);
                        return false;
                    }

                    return true;
                }).ToArray();

                if (rolesList.Count > 1)
                    rolesList.Shuffle(new Random());

                for (var i = 0; i < rolesList.Count; i++)
                {
                    ((ServerPlayer)newRoles[i]).Role = rolesList[i];
                }
            }

            //if (dealCards)
            //    return this.RoateTurnStage();
            //else
            //    return this.EmptyAction;

            return null;
        }
        public void AddPlayer(string display, Cards.Heroes.HeroCard hero, Roles role)
        {
            // TODO: Remove null terminator when roles are completed.
            var p = new ServerPlayer(display, hero?.MaxHealth ?? 4, role);
            p.DistanceModifiers = 0;
            p.HandSizeModifies = 0;

            p.TurnStageActions.Add(TurnStages.Draw, this.DefaultDraw);
            p.TurnStageActions.Add(TurnStages.Discard, this.DefaultDiscard);
            //p.TurnStageActions.Add(TurnStages.End, new Actions.ResetPlayerCountersAction());
            // Perform the card so we can finish up its special damage stuff
            //p.TurnStageActions.Add(TurnStages.AttackDamage, new Actions.PerformCardAction(() => this.CurrentPlayStage.Cards.Activator));

            //var da = new Actions.PlayerDiedAction();
            //p.TurnStageActions.Add(TurnStages.PlayerRevived, da);
            //p.TurnStageActions.Add(TurnStages.PlayerEliminated, da);
            //p.TurnStageActions.Add(TurnStages.PlayerRevivedEnd, da);
            //p.TurnStageActions.Add(TurnStages.PlayerEliminatedEnd, da);

            // TODO: Load Hero modifications. Do it AFTER assigning defaults, so our skills 
            //      can chain our draws if they want.

            if (this.players.Count == 0)
            {
                p.Left = p.Right = p;
            }
            else
            {
                p.Left = this.players.Last();
                p.Right = this.players.First();
                this.players.Last().Right = p;
                this.Players.First().Left = p;
            }

            this.players.Add(p);
        }


        public void EliminatePlayer(Player player)
        {
            this.players.Remove(player);
            player.Left.Right = player.Right;
            player.Right.Left = player.Left;

            //foreach(var card in player.Hand)
            for (var i = player.Hand.Count - 1; i >= 0; i--)
            {
                player.Hand[i].Discard();
            }

            player.PlayerArea.DiscardArea();

        }

        private void dealCardsToPlayers()
        {
            foreach (var player in this.Players)
            {
                for (var i = 0; i < 4; i++)
                {
                    var card = this.Deck.Draw();
                    card.Owner = player;
                    player.Hand.Add(card);
                }
            }
        }



        protected Controller DefaultDraw;
        protected Controller DefaultDiscard;
        //private TargetPlayer anyPlayer = new TargetPlayer(new Player("Any Player", 0, Core.Roles.Random));
        protected Controller EmptyAction = null;
    }
}
