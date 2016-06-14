using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using dab.SGS.Core.Controllers;

namespace dab.SGS.Core.Cards.Playing.Basics
{
    public enum Elemental
    {
        None,
        Fire,
        Lightning
    }

    public class AttackBasicPlayingCard : BasicPlayingCard
    {
        public Elemental Element { get; private set; }
        public AttackBasicPlayingCard(PlayingCardColor color, PlayingCardSuite suite,
            string details, Elemental element)
            : base(color, suite, (element != Elemental.None ? element.ToString() + " " : "") + "Attack", details)
        {
        }

        public override bool Play()
        {
            // Devnote: is there a scenario where we don't want this?
            //this.Context.CurrentPlayStage.Cards.Activator = this;

            return base.Play();
        }

        //public new static PlayingCard GetCardFromJson(dynamic obj)
        //{
        //    var color = (PlayingCardColor)Enum.Parse(typeof(PlayingCardColor), obj.PlayingCardColor.ToString());
        //    var suite = (PlayingCardSuite)Enum.Parse(typeof(PlayingCardSuite), obj.PlayingCardSuite.ToString());
        //    var element = (Elemental)Enum.Parse(typeof(Elemental), obj.Elemental.ToString());
        //    var details = obj.Details.ToString();
            
        //    return new AttackBasicPlayingCard(color, suite, details, element);
        //}

        public override bool IsPlayable()
        {
            return this.Context.StageControllers.Peek().IsCardPlayable(this);
        }

        public override string ToString()
        {

            return (this.Element != Elemental.None ? this.Element.ToString() + " " : "") + base.ToString();
        }
    }
}
