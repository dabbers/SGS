using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using dab.SGS.Core.Cards.Playing;
using System.Collections.Generic;
using dab.SGS.Core.Cards.Playing.Basics;

namespace dab.SGS.Core.Server.Unit
{
    [TestClass]
    public class PlayTests
    {
        public static List<PlayingCard> GetAttackDodgeAlternateDeck(int count)
        {
            var d = new List<PlayingCard>();

            for (var i = 0; i < count; i += 2)
            {
                d.Add(new AttackBasicPlayingCard(PlayingCardColor.Black, PlayingCardSuite.Club, "", Elemental.None));
                d.Add(new DodgeBasicPlayingCard(PlayingCardColor.Black, PlayingCardSuite.Club, ""));
            }

            return d;
        }

        [TestMethod]
        public void TestRoleAssignment()
        {
            var ctx = new ServerGameContext(new Deck(PlayTests.GetAttackDodgeAlternateDeck(22)));

            ctx.AddPlayer("P1", null, Roles.King);
            ctx.AddPlayer("P2", null);
            ctx.AddPlayer("P3", null);
            ctx.AddPlayer("P4", null);
            ctx.AddPlayer("P5", null);

            ctx.SetupGame();

            Assert.AreEqual(Roles.King, ((ServerPlayer)ctx.Players[0]).Role);
            Assert.AreEqual(5, ctx.Players[0].MaxHealth, "Max health for king ws not 5");
            
            var roles = new List<Roles>(Player.GetRoles(ctx.Players.Length));

            foreach (var player in ctx.Players)
            {
                roles.Remove(((ServerPlayer)player).Role);
            }

            Assert.AreEqual(0, roles.Count);

        }
    }
}
