using dab.SGS.Core.Controllers;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Cards.Playing
{
    public enum PlayingCardSuite
    {
        Club,
        Spade,
        Heart,
        Diamonds
    }

    public enum PlayingCardColor
    {
        Red,
        Black,
        None
    }

    public abstract class PlayingCard
    {
        private static int current = 0;
        private static object locker = new object();

        private static int getNextId()
        {
            lock(locker)
            {
                current++;
                return current;
            }
        }

        public int Id { get; private set; }
        public PlayingCardSuite Suite { get { return this.suite; } }
        public PlayingCardColor Color { get { return this.color; } }

        public string Display { get { return this.display; } }
        public string Details { get { return this.details; } }
        /// <summary>
        /// If this card isn't being used as what it is, what IS it being used as?
        /// </summary>
        public PlayingCard BeingUsedAs
        {
            get
            {
                return this.beingUsedAs;
            }
            set
            {
                if ((value?.Id ?? 0) > 0) throw new Exceptions.InvalidCardException(value);

                this.beingUsedAs = value;
            }
        }

        /// <summary>
        /// The current player who holds this card (either in their hand or on their playarea)
        /// </summary>
        public Player Owner { get; set; }

        public GameContext Context { get; set; }
        
        public PlayingCard(PlayingCardColor color, PlayingCardSuite suite, string display, string details)
            : this(color, suite, display, details, PlayingCard.getNextId())
        {
        }

        protected PlayingCard(PlayingCardColor color, PlayingCardSuite suite, string display, string details, int id)
        {
            this.Id = id;
            this.suite = suite;
            this.display = display;
            this.details = details;
            this.color = color;
        }

        public bool Play()
        {
            if (!this.IsPlayable() && !this.BeingUsedAsIsPlayable()) throw new Exceptions.InvalidCardSelectionException(this.Context.CurrentTurnStage);

            Context.StageControllers.Peek().Play(this);
            return true;
        }

        public bool IsPlayable()
        {
            return this.Context.StageControllers.Peek().IsCardPlayable(this);
        }

        public bool BeingUsedAsIsPlayable()
        {
            return (this.BeingUsedAs?.IsPlayable() ?? false);
        }

        public virtual bool PlayJudgement(PlayingCard card)
        {
            if (this.BeingUsedAs != null)
            {
                return this.BeingUsedAs.PlayJudgement(card);
            }

            throw new Exceptions.NoJudgementException(this);
        }

        /// <summary>
        /// Will remove any references it might have, and place itself in the discard pile.
        /// </summary>
        public virtual void Discard()
        {
            if (this.Owner.Hand.Contains(this))
                this.Owner.Hand.Remove(this);
            else if (this.Owner.PlayerArea.DelayedScrolls.Contains(this))
                this.Owner.PlayerArea.DelayedScrolls.Remove(this);
            else if (this.Owner.PlayerArea.PlusHorse == this)
                this.Owner.PlayerArea.PlusHorse = null;
            else if (this.Owner.PlayerArea.MinusHorse == this)
                this.Owner.PlayerArea.MinusHorse = null;
            else if (this.Owner.PlayerArea.Weapon == this)
                this.Owner.PlayerArea.Weapon = null;
            else if (this.Owner.PlayerArea.Shield == this)
                this.Owner.PlayerArea.Shield = null;
            else if (this.Owner.PlayerArea.FaceDownPlayingCards.Contains(this))
                this.Owner.PlayerArea.FaceDownPlayingCards.Remove(this);
            else if (this.Owner.PlayerArea.FaceUpPlayingCards.Contains(this))
                this.Owner.PlayerArea.FaceUpPlayingCards.Remove(this);
            else if (this.Context.HoldingArea.Cards.Contains(this))
                this.Context.HoldingArea.Cards.Remove(this);

            this.Owner = null;
            this.BeingUsedAs = null;

            this.Context.Deck.Discard(this);
        }

        #region IsPlayedAsType methods
        public bool IsPlayedAsType(Type type)
        {
            return this.GetType() == type || (this.BeingUsedAs?.GetType() ?? null) == type;
        }

        public bool IsPlayedAsAttack()
        {
            return this.IsPlayedAsType(typeof(Basics.AttackBasicPlayingCard));
        }
        public Basics.Elemental GetPlayedAsElement()
        {
            if (!this.IsPlayedAsAttack()) throw new Exception("TODO: Replace this exception. Cannot get element type for non attack");

            if (this is Basics.AttackBasicPlayingCard)
            {
                return ((Basics.AttackBasicPlayingCard)this).Element;
            }
            else
            {
                return ((Basics.AttackBasicPlayingCard)this.BeingUsedAs).Element;
            }
        }
        public bool IsPlayedAsElementalAttack(Basics.Elemental element)
        {
            if (!this.IsPlayedAsAttack()) return false;

            return this.GetPlayedAsElement() == element;
        }
        public bool IsPlayedAsDodge()
        {
            return this.IsPlayedAsType(typeof(Basics.DodgeBasicPlayingCard));
        }
        public bool IsPlayedAsPeach()
        {
            return this.IsPlayedAsType(typeof(Basics.PeachBasicPlayingCard));
        }
        public bool IsPlayedAsWine()
        {
            return this.IsPlayedAsType(typeof(Basics.WineBasicPlayingCard));
        }
        public bool IsPlayedAsWard()
        {
            return this.IsPlayedAsType(typeof(Scrolls.WardScrollPlayingCard));
        }
        public bool IsPlayedAsDuel()
        {
            return this.IsPlayedAsType(typeof(Scrolls.DuelScrollPlayingCard));
        }
        public bool IsPlayedAsLightning()
        {
            return this.IsPlayedAsType(typeof(Scrolls.LightningDelayedScrollPlayingCard));
        }
        public bool IsPlayedAsContentment()
        {
            return this.IsPlayedAsType(typeof(Scrolls.ContentmentDelayedScrollPlayingCard));
        }
        public bool IsPlayedAsStarvation()
        {
            return this.IsPlayedAsType(typeof(Scrolls.StarvationDelayedScrollPlayingCard));
        }
        public bool IsPlayedAsDelayScroll()
        {
            return this.IsPlayedAsLightning() || this.IsPlayedAsStarvation() || this.IsPlayedAsContentment();
        }
        public bool IsPlayedAsScroll()
        {
            return this.IsPlayedAsDelayScroll() || this.IsPlayedAsDuel() || this.IsPlayedAsContentment() || this.IsPlayedAsStarvation();
        }
        #endregion

        public override string ToString()
        {
            var color = this.color != PlayingCardColor.None ? this.color.ToString() : "No colored ";
            var suite = this.Suite.ToString();

            return color + " " + suite + " " + this.display;
        }
        public override bool Equals(object obj)
        {
            return (obj is PlayingCard ? ((PlayingCard)obj).Id == this.Id : false);
        }

        public override int GetHashCode()
        {
            return this.Id;
        }

        //public static PlayingCard GetCardFromJson(dynamic obj)
        //{
        //    string cardType = obj.Type.ToString();
        //    var type = Type.GetType(String.Format("dab.SGS.Core.PlayingCards.{0}", cardType));
        //    var fnc = type.GetRuntimeMethod("GetCardFromJson", new Type[] { obj.GetType() });

        //    return (PlayingCard)fnc.Invoke(null, new object[] { obj });
        //}
        

        private string display = String.Empty;
        private string details = String.Empty;
        private PlayingCardSuite suite;
        private PlayingCardColor color;
        private PlayingCard beingUsedAs = null;

    }
}
