import '../../../core/errors/app_exception.dart';
import 'ledger_models.dart';

/// The single source of truth for how a transaction changes account balances.
/// Positive postings increase the account's natural balance: money for assets,
/// debt for credit cards.
final class PostingCalculator {
  const PostingCalculator();

  List<PostingDraft> calculate(
    TransactionDraft draft, {
    AccountSnapshot? from,
    AccountSnapshot? to,
  }) {
    if (draft.amount.minorUnits <= 0) {
      throw const ValidationException('El importe debe ser mayor que cero.');
    }
    if (from != null && from.id != draft.fromAccountId) {
      throw const ValidationException('La cuenta de origen no coincide.');
    }
    if (to != null && to.id != draft.toAccountId) {
      throw const ValidationException('La cuenta de destino no coincide.');
    }
    _validateCurrency(draft, from, to);
    _validateSplits(draft);

    if (draft.status != TransactionStatus.confirmed) return const [];

    return switch (draft.type) {
      TransactionType.expense => [
        PostingDraft(
          accountId: _requireFrom(from).id,
          deltaMinor: _outflowDelta(
            _requireFrom(from),
            draft.amount.minorUnits,
          ),
        ),
      ],
      TransactionType.income => [
        PostingDraft(
          accountId: _requireTo(to).id,
          deltaMinor: _inflowDelta(_requireTo(to), draft.amount.minorUnits),
        ),
      ],
      TransactionType.transfer => _transfer(draft, from, to),
      TransactionType.refund => [
        PostingDraft(
          accountId: _requireTo(to).id,
          deltaMinor: _inflowDelta(_requireTo(to), draft.amount.minorUnits),
        ),
      ],
      TransactionType.adjustment => _adjustment(draft, from, to),
    };
  }

  List<PostingDraft> _transfer(
    TransactionDraft draft,
    AccountSnapshot? from,
    AccountSnapshot? to,
  ) {
    final source = _requireFrom(from);
    final destination = _requireTo(to);
    if (source.id == destination.id) {
      throw const ValidationException('Elegí dos cuentas diferentes.');
    }
    return [
      PostingDraft(
        accountId: source.id,
        deltaMinor: _outflowDelta(source, draft.amount.minorUnits),
      ),
      PostingDraft(
        accountId: destination.id,
        deltaMinor: _inflowDelta(destination, draft.amount.minorUnits),
      ),
    ];
  }

  List<PostingDraft> _adjustment(
    TransactionDraft draft,
    AccountSnapshot? from,
    AccountSnapshot? to,
  ) {
    if ((from == null) == (to == null)) {
      throw const ValidationException(
        'Un ajuste debe aumentar o disminuir exactamente una cuenta.',
      );
    }
    final account = from ?? to!;
    return [
      PostingDraft(
        accountId: account.id,
        deltaMinor: from != null
            ? _outflowDelta(account, draft.amount.minorUnits)
            : _inflowDelta(account, draft.amount.minorUnits),
      ),
    ];
  }

  void _validateCurrency(
    TransactionDraft draft,
    AccountSnapshot? from,
    AccountSnapshot? to,
  ) {
    for (final account in [from, to].whereType<AccountSnapshot>()) {
      if (account.currencyCode != draft.amount.currencyCode) {
        throw ValidationException(
          'La moneda ${draft.amount.currencyCode} no coincide con la cuenta.',
        );
      }
    }
  }

  void _validateSplits(TransactionDraft draft) {
    if (draft.splits.isEmpty) return;
    final total = draft.splits.fold<int>(
      0,
      (sum, split) => sum + split.amountMinor,
    );
    if (draft.splits.any((split) => split.amountMinor <= 0)) {
      throw const ValidationException('Cada división debe ser mayor que cero.');
    }
    if (total != draft.amount.minorUnits) {
      throw const ValidationException(
        'La suma de categorías debe coincidir exactamente con el importe.',
      );
    }
  }

  AccountSnapshot _requireFrom(AccountSnapshot? account) {
    if (account == null) {
      throw const ValidationException('Seleccioná una cuenta de origen.');
    }
    return account;
  }

  AccountSnapshot _requireTo(AccountSnapshot? account) {
    if (account == null) {
      throw const ValidationException('Seleccioná una cuenta de destino.');
    }
    return account;
  }

  int _outflowDelta(AccountSnapshot account, int amount) =>
      account.isLiability ? amount : -amount;

  int _inflowDelta(AccountSnapshot account, int amount) =>
      account.isLiability ? -amount : amount;
}
