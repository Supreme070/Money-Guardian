"""Branded HTML email template service.

10 email types across 3 tiers, all using Money Guardian brand colors.
Templates are inline HTML — version-controlled, no external dependencies.
"""

from dataclasses import dataclass
from enum import Enum


class EmailTemplate(str, Enum):
    """All email template types."""

    VERIFICATION = "verification"
    PASSWORD_RESET = "password_reset"
    WELCOME = "welcome"
    UPCOMING_CHARGE = "upcoming_charge"
    OVERDRAFT_WARNING = "overdraft_warning"
    PRICE_INCREASE = "price_increase"
    TRIAL_ENDING = "trial_ending"
    FORGOTTEN_SUBSCRIPTION = "forgotten_subscription"
    NEW_SUBSCRIPTION_DETECTED = "new_subscription_detected"
    WEEKLY_DIGEST = "weekly_digest"


@dataclass
class EmailContent:
    """Rendered email content ready to send."""

    subject: str
    plain_body: str
    html_body: str


def _base_layout(inner_html: str, unsubscribe_url: str | None = None) -> str:
    """Shared branded email wrapper.

    600px max-width, Mulish font (Arial fallback), Money Guardian branding.
    """
    unsubscribe_block = ""
    if unsubscribe_url:
        unsubscribe_block = f"""
            <p style="color: #B9B9B9; font-size: 11px; text-align: center; margin-top: 16px;">
                <a href="{unsubscribe_url}" style="color: #B9B9B9; text-decoration: underline;">
                    Unsubscribe from these emails
                </a>
            </p>
        """

    return f"""<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin: 0; padding: 0; background: #FFFFFF; -webkit-font-smoothing: antialiased;">
<div style="font-family: 'Mulish', Arial, Helvetica, sans-serif; max-width: 600px; margin: 0 auto; padding: 40px 20px;">
    <div style="text-align: center; margin-bottom: 32px;">
        <h1 style="color: #15294A; font-size: 24px; font-weight: 700; margin: 0;">Money Guardian</h1>
        <p style="color: #797878; font-size: 13px; margin-top: 4px;">Stop losing money to dumb fees.</p>
    </div>
    {inner_html}
    <p style="color: #B9B9B9; font-size: 11px; text-align: center; margin-top: 32px;">
        &copy; Money Guardian. All rights reserved.
    </p>
    {unsubscribe_block}
</div>
</body>
</html>"""


def _card(content: str) -> str:
    """Wrap content in a branded card."""
    return f"""<div style="background: #F1F1F3; border-radius: 12px; padding: 32px;">{content}</div>"""


def _cta_button(url: str, label: str) -> str:
    """Primary CTA button."""
    return f"""
    <div style="text-align: center; margin: 24px 0;">
        <a href="{url}" style="display: inline-block; background: #375EFD; color: white;
           padding: 14px 32px; border-radius: 8px; text-decoration: none;
           font-weight: 700; font-size: 16px;">{label}</a>
    </div>"""


def _status_badge(label: str, color: str) -> str:
    """Colored status badge (SAFE=green, CAUTION=gold, FREEZE=red)."""
    return f"""<span style="display: inline-block; background: {color}; color: white;
        padding: 4px 12px; border-radius: 16px; font-weight: 700; font-size: 13px;">{label}</span>"""


class EmailTemplateService:
    """Renders branded HTML email templates."""

    @staticmethod
    def render_verification(verify_url: str) -> EmailContent:
        inner = _card(f"""
            <h2 style="color: #1D2635; font-size: 20px; margin-top: 0;">Verify your email</h2>
            <p style="color: #797878; line-height: 1.6;">
                Welcome! Please verify your email address to get started.
            </p>
            {_cta_button(verify_url, "Verify Email")}
            <p style="color: #B9B9B9; font-size: 12px; text-align: center;">
                This link expires in 24 hours.
            </p>
        """)
        return EmailContent(
            subject="Verify your Money Guardian account",
            plain_body=(
                "Welcome to Money Guardian!\n\n"
                f"Please verify your email: {verify_url}\n\n"
                "This link expires in 24 hours.\n\n"
                "If you didn't create an account, ignore this email."
            ),
            html_body=_base_layout(
                inner + '<p style="color: #B9B9B9; font-size: 12px; text-align: center; margin-top: 24px;">'
                "If you didn't create an account, ignore this email.</p>"
            ),
        )

    @staticmethod
    def render_password_reset(reset_url: str) -> EmailContent:
        inner = _card(f"""
            <h2 style="color: #1D2635; font-size: 20px; margin-top: 0;">Reset your password</h2>
            <p style="color: #797878; line-height: 1.6;">
                You requested a password reset. Click below to set a new password.
            </p>
            {_cta_button(reset_url, "Reset Password")}
            <p style="color: #B9B9B9; font-size: 12px; text-align: center;">
                This link expires in 1 hour.
            </p>
        """)
        return EmailContent(
            subject="Reset your Money Guardian password",
            plain_body=(
                "You requested a password reset.\n\n"
                f"Click here to reset: {reset_url}\n\n"
                "This link expires in 1 hour.\n\n"
                "If you didn't request this, ignore this email."
            ),
            html_body=_base_layout(inner),
        )

    @staticmethod
    def render_welcome(full_name: str) -> EmailContent:
        inner = _card(f"""
            <h2 style="color: #1D2635; font-size: 20px; margin-top: 0;">Welcome, {full_name}!</h2>
            <p style="color: #797878; line-height: 1.6;">
                Your email is verified. You're all set to start protecting your money.
            </p>
            <div style="margin: 20px 0; padding: 16px; background: white; border-radius: 8px;">
                <p style="color: #1D2635; font-size: 14px; margin: 0 0 8px;">Here's what to do next:</p>
                <ul style="color: #797878; font-size: 14px; line-height: 1.8; padding-left: 20px; margin: 0;">
                    <li>Add your subscriptions manually or connect your bank</li>
                    <li>Check your Daily Pulse each morning</li>
                    <li>Get warned before surprise charges hit</li>
                </ul>
            </div>
            <p style="color: #797878; font-size: 13px; text-align: center;">
                One avoided overdraft = paid for the app.
            </p>
        """)
        return EmailContent(
            subject="Welcome to Money Guardian!",
            plain_body=(
                f"Welcome, {full_name}!\n\n"
                "Your email is verified. You're all set to start protecting your money.\n\n"
                "What to do next:\n"
                "- Add your subscriptions manually or connect your bank\n"
                "- Check your Daily Pulse each morning\n"
                "- Get warned before surprise charges hit\n\n"
                "One avoided overdraft = paid for the app.\n\n"
                "— The Money Guardian Team"
            ),
            html_body=_base_layout(inner),
        )

    @staticmethod
    def render_upcoming_charge(
        subscription_name: str,
        amount: float,
        billing_date: str,
        days_until: int,
    ) -> EmailContent:
        urgency = "today" if days_until == 0 else "tomorrow" if days_until == 1 else f"in {days_until} days"
        color = "#EF4444" if days_until == 0 else "#FBBD5C" if days_until <= 1 else "#375EFD"

        inner = _card(f"""
            <h2 style="color: #1D2635; font-size: 20px; margin-top: 0;">Upcoming Charge</h2>
            <div style="text-align: center; margin: 20px 0;">
                <p style="color: {color}; font-size: 32px; font-weight: 700; margin: 0;">${amount:.2f}</p>
                <p style="color: #797878; font-size: 14px; margin: 4px 0 0;">{subscription_name}</p>
            </div>
            <div style="background: white; border-radius: 8px; padding: 16px; text-align: center;">
                <p style="color: #1D2635; font-size: 14px; margin: 0;">
                    Charging <strong>{urgency}</strong> &middot; {billing_date}
                </p>
            </div>
        """)
        return EmailContent(
            subject=f"Upcoming: {subscription_name} — ${amount:.2f} {urgency}",
            plain_body=(
                f"Upcoming charge: {subscription_name}\n"
                f"Amount: ${amount:.2f}\n"
                f"Date: {billing_date} ({urgency})\n\n"
                "— Money Guardian"
            ),
            html_body=_base_layout(inner),
        )

    @staticmethod
    def render_overdraft_warning(
        total_balance: float,
        upcoming_total: float,
        shortfall: float,
        subscriptions_list: list[dict[str, str]],
    ) -> EmailContent:
        subs_html = ""
        subs_plain = ""
        for sub in subscriptions_list[:5]:
            subs_html += f'<li style="color: #797878; font-size: 14px; line-height: 1.8;">{sub["name"]} — ${sub["amount"]}</li>'
            subs_plain += f"  - {sub['name']} — ${sub['amount']}\n"

        inner = _card(f"""
            <div style="text-align: center; margin-bottom: 16px;">
                {_status_badge("OVERDRAFT RISK", "#EF4444")}
            </div>
            <div style="display: flex; justify-content: space-between; margin: 20px 0;">
                <div style="text-align: center; flex: 1;">
                    <p style="color: #22C55E; font-size: 24px; font-weight: 700; margin: 0;">${total_balance:.2f}</p>
                    <p style="color: #B9B9B9; font-size: 12px; margin: 4px 0 0;">Balance</p>
                </div>
                <div style="text-align: center; flex: 1;">
                    <p style="color: #EF4444; font-size: 24px; font-weight: 700; margin: 0;">${upcoming_total:.2f}</p>
                    <p style="color: #B9B9B9; font-size: 12px; margin: 4px 0 0;">Upcoming (7 days)</p>
                </div>
            </div>
            <div style="background: white; border-radius: 8px; padding: 16px;">
                <p style="color: #EF4444; font-size: 14px; font-weight: 700; margin: 0 0 8px;">
                    You may need ${shortfall:.2f} more
                </p>
                <ul style="padding-left: 20px; margin: 0;">{subs_html}</ul>
            </div>
        """)
        return EmailContent(
            subject=f"Overdraft Risk: ${shortfall:.2f} shortfall in next 7 days",
            plain_body=(
                "OVERDRAFT RISK DETECTED\n\n"
                f"Balance: ${total_balance:.2f}\n"
                f"Upcoming charges (7 days): ${upcoming_total:.2f}\n"
                f"Shortfall: ${shortfall:.2f}\n\n"
                f"Upcoming:\n{subs_plain}\n"
                "— Money Guardian"
            ),
            html_body=_base_layout(inner),
        )

    @staticmethod
    def render_price_increase(
        subscription_name: str,
        old_amount: float,
        new_amount: float,
        percent_change: float,
    ) -> EmailContent:
        inner = _card(f"""
            <h2 style="color: #1D2635; font-size: 20px; margin-top: 0;">Price Increase Detected</h2>
            <div style="background: white; border-radius: 8px; padding: 20px; text-align: center; margin: 16px 0;">
                <p style="color: #797878; font-size: 14px; margin: 0 0 8px;">{subscription_name}</p>
                <p style="margin: 0;">
                    <span style="color: #B9B9B9; font-size: 18px; text-decoration: line-through;">${old_amount:.2f}</span>
                    <span style="color: #1D2635; font-size: 12px; margin: 0 8px;">&rarr;</span>
                    <span style="color: #EF4444; font-size: 24px; font-weight: 700;">${new_amount:.2f}</span>
                </p>
                <p style="color: #FBBD5C; font-size: 13px; font-weight: 700; margin: 8px 0 0;">
                    +{percent_change:.0f}% increase
                </p>
            </div>
        """)
        return EmailContent(
            subject=f"Price Increase: {subscription_name} up {percent_change:.0f}%",
            plain_body=(
                f"Price increase detected for {subscription_name}\n\n"
                f"Old price: ${old_amount:.2f}\n"
                f"New price: ${new_amount:.2f}\n"
                f"Increase: +{percent_change:.0f}%\n\n"
                "— Money Guardian"
            ),
            html_body=_base_layout(inner),
        )

    @staticmethod
    def render_trial_ending(
        subscription_name: str,
        trial_end_date: str,
        amount_after_trial: float,
    ) -> EmailContent:
        inner = _card(f"""
            <h2 style="color: #1D2635; font-size: 20px; margin-top: 0;">Trial Ending Soon</h2>
            <div style="background: white; border-radius: 8px; padding: 20px; text-align: center; margin: 16px 0;">
                <p style="color: #797878; font-size: 14px; margin: 0 0 4px;">{subscription_name}</p>
                <p style="color: #FBBD5C; font-size: 14px; font-weight: 700; margin: 0;">
                    Trial ends {trial_end_date}
                </p>
                <p style="color: #1D2635; font-size: 20px; font-weight: 700; margin: 12px 0 0;">
                    ${amount_after_trial:.2f}/mo after trial
                </p>
            </div>
            <p style="color: #797878; font-size: 13px; text-align: center;">
                Cancel before the trial ends to avoid being charged.
            </p>
        """)
        return EmailContent(
            subject=f"Trial Ending: {subscription_name} — ${amount_after_trial:.2f}/mo starts {trial_end_date}",
            plain_body=(
                f"Trial ending soon for {subscription_name}\n\n"
                f"Trial ends: {trial_end_date}\n"
                f"Price after trial: ${amount_after_trial:.2f}/mo\n\n"
                "Cancel before the trial ends to avoid being charged.\n\n"
                "— Money Guardian"
            ),
            html_body=_base_layout(inner),
        )

    @staticmethod
    def render_forgotten_subscription(
        subscription_name: str,
        amount: float,
        last_activity_date: str,
        days_inactive: int,
    ) -> EmailContent:
        inner = _card(f"""
            <h2 style="color: #1D2635; font-size: 20px; margin-top: 0;">Forgotten Subscription?</h2>
            <div style="background: white; border-radius: 8px; padding: 20px; text-align: center; margin: 16px 0;">
                <p style="color: #797878; font-size: 14px; margin: 0 0 4px;">{subscription_name}</p>
                <p style="color: #EF4444; font-size: 24px; font-weight: 700; margin: 0;">${amount:.2f}/mo</p>
                <p style="color: #FBBD5C; font-size: 13px; margin: 8px 0 0;">
                    No activity for {days_inactive} days (since {last_activity_date})
                </p>
            </div>
            <p style="color: #797878; font-size: 13px; text-align: center;">
                Are you still using this? Consider cancelling to save ${amount * 12:.2f}/year.
            </p>
        """)
        return EmailContent(
            subject=f"Still using {subscription_name}? (${amount:.2f}/mo)",
            plain_body=(
                f"Forgotten subscription detected: {subscription_name}\n\n"
                f"Amount: ${amount:.2f}/mo\n"
                f"Last activity: {last_activity_date} ({days_inactive} days ago)\n"
                f"Potential savings: ${amount * 12:.2f}/year\n\n"
                "— Money Guardian"
            ),
            html_body=_base_layout(inner),
        )

    @staticmethod
    def render_new_subscription_detected(
        subscription_name: str,
        amount: float,
        detected_from: str,
        confidence: float,
    ) -> EmailContent:
        confidence_pct = int(confidence * 100)
        inner = _card(f"""
            <h2 style="color: #1D2635; font-size: 20px; margin-top: 0;">New Subscription Detected</h2>
            <div style="background: white; border-radius: 8px; padding: 20px; text-align: center; margin: 16px 0;">
                <p style="color: #375EFD; font-size: 18px; font-weight: 700; margin: 0;">{subscription_name}</p>
                <p style="color: #1D2635; font-size: 24px; font-weight: 700; margin: 8px 0;">${amount:.2f}/mo</p>
                <p style="color: #B9B9B9; font-size: 12px; margin: 0;">
                    Detected from {detected_from} &middot; {confidence_pct}% confidence
                </p>
            </div>
            <p style="color: #797878; font-size: 13px; text-align: center;">
                We found this in your {detected_from}. Open the app to confirm or dismiss.
            </p>
        """)
        return EmailContent(
            subject=f"New subscription found: {subscription_name} (${amount:.2f}/mo)",
            plain_body=(
                f"New subscription detected: {subscription_name}\n\n"
                f"Amount: ${amount:.2f}/mo\n"
                f"Source: {detected_from}\n"
                f"Confidence: {confidence_pct}%\n\n"
                "Open the app to confirm or dismiss.\n\n"
                "— Money Guardian"
            ),
            html_body=_base_layout(inner),
        )

    @staticmethod
    def render_weekly_digest(
        pulse_status: str,
        safe_to_spend: float,
        upcoming_charges_list: list[dict[str, str]],
        monthly_total: float,
        subscription_count: int,
    ) -> EmailContent:
        status_colors = {"SAFE": "#22C55E", "CAUTION": "#FBBD5C", "FREEZE": "#EF4444"}
        color = status_colors.get(pulse_status.upper(), "#375EFD")

        charges_html = ""
        charges_plain = ""
        for charge in upcoming_charges_list[:7]:
            charges_html += f"""
                <tr>
                    <td style="color: #797878; font-size: 13px; padding: 6px 0;">{charge["name"]}</td>
                    <td style="color: #1D2635; font-size: 13px; padding: 6px 0; text-align: right; font-weight: 700;">${charge["amount"]}</td>
                    <td style="color: #B9B9B9; font-size: 12px; padding: 6px 0; text-align: right;">{charge["date"]}</td>
                </tr>"""
            charges_plain += f"  - {charge['name']}: ${charge['amount']} ({charge['date']})\n"

        inner = _card(f"""
            <h2 style="color: #1D2635; font-size: 20px; margin-top: 0;">Your Weekly Money Pulse</h2>
            <div style="text-align: center; margin: 20px 0;">
                {_status_badge(pulse_status.upper(), color)}
                <p style="color: #1D2635; font-size: 28px; font-weight: 700; margin: 12px 0 0;">
                    ${safe_to_spend:.2f}
                </p>
                <p style="color: #B9B9B9; font-size: 12px; margin: 0;">safe to spend this week</p>
            </div>
            <div style="background: white; border-radius: 8px; padding: 16px; margin: 16px 0;">
                <p style="color: #1D2635; font-size: 14px; font-weight: 700; margin: 0 0 8px;">
                    Upcoming This Week
                </p>
                <table style="width: 100%; border-collapse: collapse;">{charges_html}</table>
            </div>
            <div style="display: flex; gap: 16px; margin-top: 16px;">
                <div style="flex: 1; background: white; border-radius: 8px; padding: 12px; text-align: center;">
                    <p style="color: #375EFD; font-size: 20px; font-weight: 700; margin: 0;">{subscription_count}</p>
                    <p style="color: #B9B9B9; font-size: 11px; margin: 4px 0 0;">Active subs</p>
                </div>
                <div style="flex: 1; background: white; border-radius: 8px; padding: 12px; text-align: center;">
                    <p style="color: #1D2635; font-size: 20px; font-weight: 700; margin: 0;">${monthly_total:.2f}</p>
                    <p style="color: #B9B9B9; font-size: 11px; margin: 4px 0 0;">Monthly total</p>
                </div>
            </div>
        """)
        return EmailContent(
            subject=f"Weekly Pulse: {pulse_status.upper()} — ${safe_to_spend:.2f} safe to spend",
            plain_body=(
                f"YOUR WEEKLY MONEY PULSE: {pulse_status.upper()}\n\n"
                f"Safe to spend: ${safe_to_spend:.2f}\n"
                f"Active subscriptions: {subscription_count}\n"
                f"Monthly total: ${monthly_total:.2f}\n\n"
                f"Upcoming this week:\n{charges_plain}\n"
                "— Money Guardian"
            ),
            html_body=_base_layout(inner),
        )
